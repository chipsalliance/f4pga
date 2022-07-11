#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

import os
import random
import shutil
import tkinter
import tempfile
from pathlib import Path
from contextlib import contextmanager

from f4pga.flows.common import F4PGAException, ResolutionEnv, decompose_depname, sub
from f4pga.flows.module import Module, ModuleContext, ModuleRuntimeException


_tcl_prepare_dry = """
# Override exec procedure for a dry pass
proc exec args {
    return
}

# Make unknown procedure ignore everything. This will make a script containing
# invalid commands pass a dry run, but it will eventually fail, when executed
# by Yosys.
proc unknown args {
    return
}
"""

_rand_charset = "abcdefghijklmnopqrstuwvxyzABCDEFGHIJKLMNOPQRSTUWVXYZ0123456789"


def randstr(len: int):
    return "".join([random.choice(_rand_charset) for _ in range(len)])


class YosysTempFiles:
    dir: Path
    tempfiles: "dict[str, Path]"

    def __init__(self):
        self.dir = Path(tempfile.mkdtemp(prefix="f4pga_yosys_"))
        self.tempfiles = {}

    def bind_file(self, var_name: str) -> Path:
        path = self.tempfiles.get(var_name)
        if path is not None:
            return path
        while True:
            name = randstr(16)
            path = self.dir.joinpath(name)
            if not path.exists():
                break

        self.tempfiles[name] = path

        return path

    def cleanup(self):
        for tempfile_path in self.tempfiles.values():
            if tempfile_path.exists():
                os.remove(tempfile_path)
        os.rmdir(self.dir)


@contextmanager
def yosys_temp_files(tempfiles: "set[str]"):
    ytf = YosysTempFiles()
    for file_var in tempfiles:
        ytf.bind_file(file_var)

    try:
        yield ytf
    finally:
        ytf.cleanup()


def store_exception(o, attr_name):
    """
    Stores an exception in `attr_name` field of `o` if raised by a decorated
    function. This is useful if the function is called in a context that discards
    details of an exception when the function throws.
    """

    def inner(f, o=o, attr_name=attr_name):
        def innermost(*args, **kwargs):
            r = None
            try:
                r = f(*args, **kwargs)
            except Exception as e:
                setattr(o, attr_name, e)
                raise e
            setattr(o, attr_name, None)
            return r

        return innermost

    return inner


class YosysScriptMeta:
    inputs: "set[str]"
    outputs: "dict[str, tuple[str,str]]"
    values: "set[str]"
    tempfiles: "set[str]"
    exception: "Exception | None"

    def __init__(self, r_env: ResolutionEnv):
        self.inputs = set()
        self.outputs = {}
        self.values = set()
        self.tempfiles = set()
        self.exception = None

        def _build_tcl_f4pga_cmd(tcl: tkinter.Tcl, tempfiles: YosysTempFiles, meta=self, r_env: ResolutionEnv = r_env):
            @store_exception(meta, "exception")
            def tcl_f4pga(*args, meta=self, tcl: tkinter.Tcl = tcl, r_env: ResolutionEnv = r_env):
                """
                Implementation of dry-pass `f4pga` command for F4PGA yosys scripts.
                This command is used to describe I/O of the script
                Usage:
                 1) f4pga take dependencyName
                 2) f4pga produce dependencyName pathExpr ?-meta metadata?
                 3) f4pga value valueName
                 4) f4pga tempfile pathVariableName

                  * 1: Take dependency, use `dependencyName`* to hold path to it.
                       `?` qualifier is accepted.
                  * 2: Produce dependency. The script must produce a file with
                       a path name
                  * 3: Use a value provided by f4pga. `?` qualifier is accepted.
                  * 4: Provide a temprary file. The path will be assigned to
                       `pathVariableName`*.

                  * All variables set by `f4pga` command will have `f4pga_` prefix.
                """
                args = list(args)
                if len(args) < 1:
                    raise F4PGAException(message="f4pga (tcl): no action specified")
                action = args[0]
                if action == "value":
                    if len(args) != 2:
                        raise F4PGAException(message="f4pga value (tcl): wrong arguments count")
                    meta.values.add(args[1])
                    name, _ = decompose_depname(args[1])
                    value = r_env.values.get(name)
                    if value is None:
                        value = ""
                    tcl.setvar(f"f4pga_{name}", "${" + name + "}")
                elif action == "tempfile":
                    if len(args) != 2:
                        raise F4PGAException(message="f4pga tempfile (tcl): wrong arguments count")
                    meta.tempfiles.add(args[1])
                    path = tempfiles.bind_file(args[1])
                    tcl.setvar(f"f4pga_{args[1]}", path)
                elif action == "take":
                    if len(args) != 2:
                        raise F4PGAException(message="f4pga take (tcl): wrong arguments count")
                    meta.inputs.add(args[1])
                    name, _ = decompose_depname(args[1])
                    tcl.setvar(f"f4pga_{name}", "${:" + name + "}")
                elif action == "produce":
                    argno = 0
                    meta_d = None
                    name = None
                    pathexpr = None
                    args.pop(0)
                    while len(args) != 0:
                        arg = args[0]
                        if arg == "-meta":
                            if len(args) < 2:
                                raise F4PGAException(
                                    message="f4pga produce -meta (tcl) - expected" "metadata parameter"
                                )
                            meta_d = args[1]
                            args.pop(0)
                            args.pop(0)
                            continue
                        elif argno == 0:
                            name = arg
                            args.pop(0)
                            argno += 1
                            continue
                        elif argno == 1:
                            pathexpr = arg
                            args.pop(0)
                            argno += 1
                            continue
                        elif argno > 1:
                            raise F4PGAException(message="f4pga produce (tcl) - too many arguments")
                        else:
                            raise F4PGAException(message="f4pga produce (tcl) - unrecognized " f"flag {arg}")
                    meta.outputs[name] = (pathexpr, meta_d)
                    tcl.setvar(f"f4pga_{name}", "${:" + name + "}")

            return tcl_f4pga

        self.build_tcl_f4pga_cmd = _build_tcl_f4pga_cmd

    def interrogate_tcl_script(self, *script_paths: str):
        """
        Run the yosys TCL script with fake implementations of yosys commands
        in order to discover its I/O.

        WARNING: This requires the Yosys script to behave in a deterministic
        manner.
        """

        with yosys_temp_files(self.tempfiles) as tf:
            tcl = tkinter.Tcl()
            tcl.eval(_tcl_prepare_dry)
            tcl.createcommand("f4pga", self.build_tcl_f4pga_cmd(tcl, tf))

            try:
                for path in script_paths:
                    tcl.evalfile(path)
            except tkinter.TclError as e:
                # tkinter discards exceptions thrown by commands implemented in
                # python. To recover those exceptions we store them early in
                # `YosysScriptMeta.exception` field using `store_exception`
                # decorator.
                if self.exception is not None:
                    raise self.exception
                else:
                    raise e

    def make_env(self, ctx: ModuleContext, tempfiles: YosysTempFiles):
        env = {}

        # create environmental variables
        for take_name_enc in self.inputs:
            take_name, _ = decompose_depname(take_name_enc)
            take = getattr(ctx.takes, take_name)
            if take is not None:
                env[f"DEP_{take_name}"] = take
            else:
                env[f"DEP_{take_name}"] = ""
        for prod_name in self.outputs.keys():
            env[f"DEP_{prod_name}"] = getattr(ctx.produces, prod_name)
        for val_name_enc in self.values:
            val_name, _ = decompose_depname(val_name_enc)
            val = getattr(ctx.values, val_name)
            if val is not None:
                env[f"VAL_{val_name}"] = val
            else:
                env[f"VAL_{val_name}"] = ""
        for tmp_name in self.tempfiles:
            env[f"TMP_{tmp_name}"] = str(tempfiles.bind_file(tmp_name))

        # shellify lists
        for key, value in env.items():
            if type(value) is list:
                value = " ".join(value)
                env[key] = value

        return env


class YosysModule(Module):
    extra_products: "list[str]"
    yosys_meta: YosysScriptMeta
    tcl_script_path: str
    common_script_dir: Path

    def map_io(self, ctx: ModuleContext):
        mapping = {}
        for key, (pathexpr, _) in self.yosys_meta.outputs.items():
            mapping[key] = ctx.r_env.resolve(pathexpr)

        return mapping

    def execute(self, ctx: ModuleContext):
        f4pga_tcl = str(self.common_script_dir / "f4pga_exec.tcl")
        common_tcl = str(self.common_script_dir / "common.tcl")
        cmd = f"tcl {f4pga_tcl}; tcl {common_tcl}; tcl {self.tcl_script_path}"
        with yosys_temp_files(self.yosys_meta.tempfiles) as tf:
            extra_opts = []

            log_path = getattr(ctx.outputs, f"yosys_{self.name}_log")
            if log_path is not None:
                extra_opts += ["-l", log_path]

            env = self.yosys_meta.make_env(ctx, tf)
            yosys = shutil.which("yosys")

            if ctx.values.yosys_plugins is not None:
                for plugin in ctx.values.yosys_plugins:
                    cmd = f"plugin -i {plugin}; {cmd}"

            yield "Running Yosys TCL script..."
            sub(*([yosys, "-p", cmd] + extra_opts), env=env)

    def __init__(self, params, r_env: ResolutionEnv, instance_name):
        super().__init__(params, r_env, instance_name)

        def param_require(name: str):
            param = params.get(name)
            if name is None:
                raise ModuleRuntimeException("Yosys module requires param `{name}`")
            return param

        self.no_of_phases = 1

        self.tcl_script_path = r_env.resolve(param_require("tcl_script"))
        self.common_script_dir = Path(r_env.values.get("auxDir")).joinpath("tool_data/yosys/scripts/common")

        self.yosys_meta = YosysScriptMeta(r_env)
        self.yosys_meta.interrogate_tcl_script(str(self.common_script_dir.joinpath("common.tcl")), self.tcl_script_path)

        self.takes = list(self.yosys_meta.inputs)
        self.produces = [f"yosys_{self.name}_log!"] + list(self.yosys_meta.outputs.keys())

        values = set(self.yosys_meta.values)
        values.add("yosys_plugins?")
        self.values = list(values)

        self.prod_meta = {}
        for key, (_, desc) in self.yosys_meta.outputs.items():
            self.prod_meta[key] = desc

        extra_meta = params.get("prod_meta")
        if extra_meta:
            self.prod_meta.update(extra_meta)


ModuleClass = YosysModule
