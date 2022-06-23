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

from pathlib import Path

from f4pga.flows.common import sub as common_sub
from f4pga.flows.module import Module, ModuleContext


class PlaceConstraintsModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {"place_constraints": f"{Path(ctx.takes.net).stem!s}.preplace"}

    def execute(self, ctx: ModuleContext):
        yield "Saving place constraint data..."
        with Path(ctx.outputs.place_constraints).open("wb") as wfptr:
            wfptr.write(
                common_sub(
                    *(
                        [
                            "python3",
                            ctx.values.script,
                            "--net",
                            ctx.takes.net,
                            "--arch",
                            str(Path(ctx.share) / "arch" / ctx.values.device / "arch.timing.xml"),
                            "--blif",
                            ctx.takes.eblif,
                            "--input",
                            ctx.takes.io_place,
                            "--db_root",
                            common_sub("prjxray-config").decode().replace("\n", ""),
                            "--part",
                            ctx.values.part_name,
                        ]
                        + (options_dict_to_list(ctx.values.extra_opts) if ctx.values.extra_opts else [])
                    )
                )
            )

    def __init__(self, params, r_env, instance_name):
        super().__init__(params, r_env, instance_name)
        self.no_of_phases = 2
        self.takes = ["eblif", "net", "io_place"]
        self.produces = ["place_constraints"]
        self.values = ["device", "part_name", "script", "extra_opts?"]


ModuleClass = PlaceConstraintsModule
