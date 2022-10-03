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

module top (
    input [0:7] in,
    output B1,
    B2,
    B3,
    B4,
    B5,
    B6,
    B7,
    B8,
    B9,
    B10
);
  assign B1  = in[0] & in[1];
  assign B2  = in[0] | in[1];
  assign B3  = in[0]~&in[1];
  assign B4  = in[0]~|in[1];
  assign B5  = in[0] ^ in[1];
  assign B6  = in[0] ~^ in[1];
  assign B7  = ~in[0];
  assign B8  = in[0];
  assign B9  = in[0:1] && in[2:3];
  assign B10 = in[0:1] || in[2:3];
endmodule
