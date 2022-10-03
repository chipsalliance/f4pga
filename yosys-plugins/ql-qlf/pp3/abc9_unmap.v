// Copyright 2020-2022 F4PGA Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
module $__PP3_DFFEPC_SYNCONLY (
  output Q,
  input D,
  input CLK,
  input EN,
);

// For some reason ABC9 adds init attributes to wires even though they were removed before mapping.
// As a workaround, remove any init attributes that get reintroduced.
wire _TECHMAP_REMOVEINIT_Q_ = 1;

dffepc _TECHMAP_REPLACE_ (.Q(Q), .D(D), .CLK(CLK), .EN(EN), .PRE(1'b0), .CLR(1'b0));

endmodule
