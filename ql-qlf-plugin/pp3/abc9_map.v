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

// This file exists to map purely-synchronous flops to ABC9 flops, while 
// mapping flops with asynchronous-set/clear as boxes, this is because ABC9 
// doesn't support asynchronous-set/clear flops in sequential synthesis.

module dffepc (
  output Q,
  input D,
  input CLK,
  input EN,
  input CLR,
  input PRE
);

parameter INIT = 1'b0;

parameter _TECHMAP_CONSTMSK_CLR_ = 1'b0;
parameter _TECHMAP_CONSTMSK_PRE_ = 1'b0;
parameter _TECHMAP_CONSTVAL_CLR_ = 1'b0;
parameter _TECHMAP_CONSTVAL_PRE_ = 1'b0;

if (_TECHMAP_CONSTMSK_CLR_ != 1'b0 && _TECHMAP_CONSTMSK_PRE_ != 1'b0 && _TECHMAP_CONSTVAL_CLR_ == 1'b0 && _TECHMAP_CONSTVAL_PRE_ == 1'b0)
    $__PP3_DFFEPC_SYNCONLY _TECHMAP_REPLACE_ (.Q(Q), .D(D), .CLK(CLK), .EN(EN));
else
    wire _TECHMAP_FAIL_ = 1;

endmodule
