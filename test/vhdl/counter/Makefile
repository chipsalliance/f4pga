# Copyright (C) 2020-2022 F4PGA Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

synth:
	docker run --rm \
	-v /$(shell pwd)://wrk -w //wrk \
	gcr.io/hdl-containers/ghdl \
	ghdl synth --std=08 --out=verilog counter.vhd -e Arty_Counter > Arty_Counter.v

synth-plugin:
	docker run --rm \
	-v /$(shell pwd)://wrk -w //wrk \
	gcr.io/hdl-containers/ghdl/yosys \
	yosys -m ghdl -p 'ghdl --std=08 counter.vhd -e Arty_Counter; write_verilog Arty_Counter.v'
