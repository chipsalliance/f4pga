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

from pyAttributes.ArgParseAttributes import (
    ArgParseMixin,
    ArgumentAttribute,
    Attribute,
    CommandAttribute,
    CommonSwitchArgumentAttribute,
    DefaultAttribute,
    SwitchArgumentAttribute,
)


class CLI(ArgParseMixin):
    HeadLine = "FOSS Flows For FPGA (F4PGA) command-line tool"

    def __init__(self):
        import argparse
        import textwrap

        # Call constructor of the main interitance tree
        super().__init__()
        # Call constructor of the ArgParseMixin
        ArgParseMixin.__init__(
            self,
            description=textwrap.dedent(
                """
                Long description...
                """
            ),
            epilog=textwrap.fill("Happy hacking!"),
            formatter_class=argparse.ArgumentDefaultsHelpFormatter,
            add_help=False,
        )

    def PrintHeadline(self):
        print("{line}".format(line="=" * 80))
        print("{headline: ^80s}".format(headline=self.HeadLine))
        print("{line}".format(line="=" * 80))

    @CommonSwitchArgumentAttribute(
        "-n",
        "--noexec",
        dest="noexec",
        help="Print commands but do not execute them.",
        default=False,
    )
    def Run(self):
        ArgParseMixin.Run(self)

    @DefaultAttribute()
    def HandleDefault(self, args):
        self.PrintHeadline()
        self.MainParser.print_help()

    @CommandAttribute("help", help="Display help page(s) for the given command name.")
    @ArgumentAttribute(
        dest="Command",
        type=str,
        nargs="?",
        help="Print help page(s) for a command.",
    )
    def HandleHelp(self, args):
        if args.Command == "help":
            print("This is a recursion ...")
            return
        if args.Command is None:
            self.PrintHeadline()
            self.MainParser.print_help()
        else:
            try:
                self.PrintHeadline()
                self.SubParsers[args.Command].print_help()
            except KeyError:
                print("command {0} is unknown.".format(args.Command))

    @CommandAttribute(
        "analysis",
        help="???.",
        description="???."
    )
    def HandleAnalysis(self, args):
        print("ANALYSIS!")

    @CommandAttribute(
        "synth",
        help="???.",
        description="???."
    )
    def HandleSynth(self, args):
        print("SYNTH!")

    @CommandAttribute(
        "pack",
        help="???.",
        description="???."
    )
    def HandlePack(self, args):
        print("PACK!")

    @CommandAttribute(
        "generate",
        help="???.",
        description="???."
    )
    def HandleGenerate(self, args):
        print("GENERATE!")

    # FIXME This is a subcommand of 'generate'
    @CommandAttribute(
        "constraints",
        help="???.",
        description="???."
    )
    def HandleGenerateConstraints(self, args):
        print("GENERATE CONSTRAINTS!")

    # FIXME This is a subcommand of 'generate'
    @CommandAttribute(
        "fasm2bels",
        help="???.",
        description="???."
    )
    def HandleGenerateFASM2Bells(self, args):
        print("GENERATE FASM2BELLS!")

    @CommandAttribute(
        "write",
        help="???.",
        description="???."
    )
    def HandleWrite(self, args):
        print("WRITE!")

    # FIXME This is a subcommand of 'write'
    @CommandAttribute(
        "fasm",
        help="???.",
        description="???."
    )
    def HandleWriteFASM(self, args):
        print("WRITE FASM!")

    # FIXME This is a subcommand of 'write'
    @CommandAttribute(
        "bitstream",
        help="???.",
        description="???."
    )
    def HandleWriteBitstream(self, args):
        print("WRITE BITSTREAM!")

    # FIXME This is a subcommand of 'write'
    @CommandAttribute(
        "bitheader",
        help="???.",
        description="???."
    )
    def HandleWriteBitheader(self, args):
        print("WRITE BITHEADER!")

#    # FIXME This is a subcommand of 'write'
#    @CommandAttribute(
#        "fasm2bels",
#        help="???.",
#        description="???."
#    )
#    def HandleWriteFASM2Bells(self, args):
#        print("WRITE FASM2BELLS!")

    # FIXME This is a subcommand of 'write'
    @CommandAttribute(
        "jlink",
        help="???.",
        description="???."
    )
    def HandleWriteJlink(self, args):
        print("WRITE JLINK!")

    # FIXME This is a subcommand of 'write'
    @CommandAttribute(
        "openocd",
        help="???.",
        description="???."
    )
    def HandleWriteOpenOCD(self, args):
        print("WRITE OPENOCD!")

    @CommandAttribute(
        "vpr",
        help="???.",
        description="???."
    )
    def HandleVPR(self, args):
        print("VPR!")

    @CommandAttribute(
        "ql",
        help="???.",
        description="???."
    )
    def HandleQL(self, args):
        print("QL!")


def main():
    CLI().Run()


if __name__ == "__main__":
    main()
