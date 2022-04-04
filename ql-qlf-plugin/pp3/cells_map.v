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

module \$_MUX8_ (
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    S,
    T,
    U,
    Y
);
  input A, B, C, D, E, F, G, H, S, T, U;
  output Y;
  mux8x0 _TECHMAP_REPLACE_ (
      .A (A),
      .B (B),
      .C (C),
      .D (D),
      .E (E),
      .F (F),
      .G (G),
      .H (H),
      .S0(S),
      .S1(T),
      .S2(U),
      .Q (Y)
  );
endmodule

module \$_MUX4_ (
    A,
    B,
    C,
    D,
    S,
    T,
    U,
    Y
);
  input A, B, C, D, S, T, U;
  output Y;
  mux4x0 _TECHMAP_REPLACE_ (
      .A (A),
      .B (B),
      .C (C),
      .D (D),
      .S0(S),
      .S1(T),
      .Q (Y)
  );
endmodule
