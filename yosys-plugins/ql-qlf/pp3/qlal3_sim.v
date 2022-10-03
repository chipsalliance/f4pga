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

(* blackbox *)
(* keep *)
module qlal3_left_assp_macro (
  input         A2F_ACK,
  output [ 7:0] A2F_ADDR,
  output [ 7:0] A2F_Control,
  input  [ 7:0] A2F_GP_IN,
  output [ 7:0] A2F_GP_OUT,
  input  [ 7:0] A2F_RD_DATA,
  output        A2F_REQ,
  output        A2F_RWn,
  input  [ 6:0] A2F_Status,
  output [ 7:0] A2F_WR_DATA,
  input  [31:0] Amult0,
  input  [31:0] Bmult0,
  output [63:0] Cmult0,
  input  [ 8:0] RAM0_ADDR,
  input         RAM0_CLK,
  input         RAM0_CLKS,
  output [35:0] RAM0_RD_DATA,
  input         RAM0_RD_EN,
  input         RAM0_RME_af,
  input  [ 3:0] RAM0_RM_af,
  input         RAM0_TEST1_af,
  input  [ 3:0] RAM0_WR_BE,
  input  [35:0] RAM0_WR_DATA,
  input         RAM0_WR_EN,
  input  [11:0] RAM8K_P0_ADDR,
  input         RAM8K_P0_CLK,
  input         RAM8K_P0_CLKS,
  input  [ 1:0] RAM8K_P0_WR_BE,
  input  [16:0] RAM8K_P0_WR_DATA,
  input         RAM8K_P0_WR_EN,
  input  [11:0] RAM8K_P1_ADDR,
  input         RAM8K_P1_CLK,
  input         RAM8K_P1_CLKS,
  output [16:0] RAM8K_P1_RD_DATA,
  input         RAM8K_P1_RD_EN,
  input         RAM8K_P1_mux,
  input         RAM8K_RME_af,
  input  [ 3:0] RAM8K_RM_af,
  input         RAM8K_TEST1_af,
  output        RAM8K_fifo_almost_empty,
  output        RAM8K_fifo_almost_full,
  output [ 3:0] RAM8K_fifo_empty_flag,
  input         RAM8K_fifo_en,
  output [ 3:0] RAM8K_fifo_full_flag,
  input         RESET_n,
  input         RESET_nS,
  input         SEL_18_bottom,
  input         SEL_18_left,
  input         SEL_18_right,
  input         SEL_18_top,
  input         SPI_CLK,
  input         SPI_CLKS,
  output        SPI_MISO,
  output        SPI_MISOe,
  input         SPI_MOSI,
  input         SPI_SSn,
  output        SYSCLK,
  output        SYSCLK_x2,
  input         Valid_mult0,
  input  [ 3:0] af_burnin_mode,
  input  [31:0] af_dev_id,
  input         af_fpga_int_en,
  input         af_opt_0,
  input         af_opt_1,
  input         \af_plat_id[0] ,
  input         \af_plat_id[1] ,
  input         \af_plat_id[2] ,
  input         \af_plat_id[3] ,
  input         \af_plat_id[4] ,
  input         \af_plat_id[5] ,
  input         \af_plat_id[6] ,
  input         \af_plat_id[7] ,
  input         af_spi_cpha,
  input         af_spi_cpol,
  input         af_spi_lsbf,
  input         default_SPI_IO_mux,
  input         drive_io_en_0,
  input         drive_io_en_1,
  input         drive_io_en_2,
  input         drive_io_en_3,
  input         drive_io_en_4,
  input         drive_io_en_5,
  output        fast_clk_out,
  input  [ 7:0] int_i,
  output        int_o,
  input         osc_en,
  input         osc_fsel,
  input  [ 2:0] osc_sel,
  input  [ 1:0] reg_addr_int,
  input         reg_clk_int,
  input         reg_clk_intS,
  output [ 7:0] reg_rd_data_int,
  input         reg_rd_en_int,
  input  [ 7:0] reg_wr_data_int,
  input         reg_wr_en_int
);
endmodule

(* blackbox *)
(* keep *)
module qlal3_right_assp_macro (
  input  [31:0] Amult1,
  input  [31:0] Bmult1,
  output [63:0] Cmult1,
  output        DrivingI2cBusOut,
  input  [ 8:0] RAM1_ADDR,
  input         RAM1_CLK,
  input         RAM1_CLKS,
  output [35:0] RAM1_RD_DATA,
  input         RAM1_RD_EN,
  input         RAM1_RME_af,
  input  [ 3:0] RAM1_RM_af,
  input         RAM1_TEST1_af,
  input  [ 3:0] RAM1_WR_BE,
  input  [35:0] RAM1_WR_DATA,
  input         RAM1_WR_EN,
  input  [ 8:0] RAM2_P0_ADDR,
  input         RAM2_P0_CLK,
  input         RAM2_P0_CLKS,
  input  [ 3:0] RAM2_P0_WR_BE,
  input  [31:0] RAM2_P0_WR_DATA,
  input         RAM2_P0_WR_EN,
  input  [ 8:0] RAM2_P1_ADDR,
  input         RAM2_P1_CLK,
  input         RAM2_P1_CLKS,
  output [31:0] RAM2_P1_RD_DATA,
  input         RAM2_P1_RD_EN,
  input         RAM2_RME_af,
  input  [ 3:0] RAM2_RM_af,
  input         RAM2_TEST1_af,
  input  [ 8:0] RAM3_P0_ADDR,
  input         RAM3_P0_CLK,
  input         RAM3_P0_CLKS,
  input  [31:0] RAM3_P0_WR_DATA,
  input  [ 3:0] RAM3_P0_WR_EN,
  input  [ 8:0] RAM3_P1_ADDR,
  input         RAM3_P1_CLK,
  input         RAM3_P1_CLKS,
  output [31:0] RAM3_P1_RD_DATA,
  input         RAM3_P1_RD_EN,
  input         RAM3_RME_af,
  input  [ 3:0] RAM3_RM_af,
  input         RAM3_TEST1_af,
  input         SCL_i,
  output        SCL_o,
  output        SCL_oen,
  input         SDA_i,
  output        SDA_o,
  output        SDA_oen,
  input         Valid_mult1,
  input         al_clr_i,
  output        al_o,
  input         al_stick_en_i,
  input         arst,
  input         arstS,
  output        i2c_busy_o,
  input         rxack_clr_i,
  output        rxack_o,
  input         rxack_stick_en_i,
  output        tip_o,
  output        wb_ack,
  input  [ 2:0] wb_adr,
  input         wb_clk,
  input         wb_clkS,
  input         wb_cyc,
  input  [ 7:0] wb_dat_i,
  output [ 7:0] wb_dat_o,
  output        wb_inta,
  input         wb_rst,
  input         wb_rstS,
  input         wb_stb,
  input         wb_we
);
endmodule

// ============================================================================
// Cells common to ASSPL and ASSPR

(* blackbox *)
module qlal3_mult_32x32_cell (
  input  [31:0] Amult,
  input  [31:0] Bmult,
  input         Valid_mult,
  output [63:0] Cmult
);
endmodule

(* blackbox *)
module qlal3_ram_512x36_cell (
  input  [ 8:0] RAM_ADDR,
  input         RAM_CLK,
  input         RAM_CLKS,
  output [35:0] RAM_RD_DATA,
  input         RAM_RD_EN,
  input         RAM_RME_af,
  input  [ 3:0] RAM_RM_af,
  input         RAM_TEST1_af,
  input  [ 3:0] RAM_WR_BE,
  input  [35:0] RAM_WR_DATA,
  input         RAM_WR_EN
);
endmodule

(* blackbox *)
module qlal3_ram_512x32_cell (
  input  [ 8:0] RAM_P0_ADDR,
  input         RAM_P0_CLK,
  input         RAM_P0_CLKS,
  input  [ 3:0] RAM_P0_WR_BE,
  input  [31:0] RAM_P0_WR_DATA,
  input         RAM_P0_WR_EN,
  input  [ 8:0] RAM_P1_ADDR,
  input         RAM_P1_CLK,
  input         RAM_P1_CLKS,
  output [31:0] RAM_P1_RD_DATA,
  input         RAM_P1_RD_EN,
  input         RAM_RME_af,
  input  [ 3:0] RAM_RM_af,
  input         RAM_TEST1_af,
);
endmodule

(* blackbox *)
module qlal3_ram_4096x17_cell (
  input  [11:0] RAM_P0_ADDR,
  input         RAM_P0_CLK,
  input         RAM_P0_CLKS,
  input  [ 1:0] RAM_P0_WR_BE,
  input  [16:0] RAM_P0_WR_DATA,
  input         RAM_P0_WR_EN,
  input  [11:0] RAM_P1_ADDR,
  input         RAM_P1_CLK,
  input         RAM_P1_CLKS,
  output [16:0] RAM_P1_RD_DATA,
  input         RAM_P1_RD_EN,
  input         RAM_P1_mux,
  input         RAM_RME_af,
  input  [ 3:0] RAM_RM_af,
  input         RAM_TEST1_af,
  output        RAM_fifo_almost_empty,
  output        RAM_fifo_almost_full,
  output [ 3:0] RAM_fifo_empty_flag,
  input         RAM_fifo_en,
  output [ 3:0] RAM_fifo_full_flag
);
endmodule

// ============================================================================
// Cells specific to ASSPL

(* blackbox *)
module qlal3_spi_cell (
  input         A2F_ACK,
  output [ 7:0] A2F_ADDR,
  output [ 7:0] A2F_Control,
  input  [ 7:0] A2F_GP_IN,
  output [ 7:0] A2F_GP_OUT,
  input  [ 7:0] A2F_RD_DATA,
  output        A2F_REQ,
  output        A2F_RWn,
  input  [ 6:0] A2F_Status,
  output [ 7:0] A2F_WR_DATA,

  input         af_spi_cpha,
  input         af_spi_cpol,
  input         af_spi_lsbf,

  input         SPI_CLK,
  input         SPI_CLKS,
  output        SPI_MISO,
  output        SPI_MISOe,
  input         SPI_MOSI,
  input         SPI_SSn
);
endmodule

(* blackbox *)
module qlal3_interrupt_controller_cell (
  input         af_fpga_int_en,
  input  [ 7:0] int_i,
  output        int_o,

  input  [ 1:0] reg_addr_int,
  input         reg_clk_int,
  input         reg_clk_intS,
  output [ 7:0] reg_rd_data_int,
  input         reg_rd_en_int,
  input  [ 7:0] reg_wr_data_int,
  input         reg_wr_en_int
);
endmodule

(* blackbox *)
module qlal3_oscillator_cell (
  input         osc_en,
  input         osc_fsel,
  input  [ 2:0] osc_sel,
  output        fast_clk_out
);
endmodule

(* blackbox *)
module qlal3_io_control_cell (
  input         default_SPI_IO_mux,
  input         drive_io_en_0,
  input         drive_io_en_1,
  input         drive_io_en_2,
  input         drive_io_en_3,
  input         drive_io_en_4,
  input         drive_io_en_5
);
endmodule

(* blackbox *)
module qlal3_system_cell (
  input         RESET_n,
  input         RESET_nS,
  input         SEL_18_bottom,
  input         SEL_18_left,
  input         SEL_18_right,
  input         SEL_18_top,
  output        SYSCLK,
  output        SYSCLK_x2,
  input  [ 3:0] af_burnin_mode,
  input  [31:0] af_dev_id,
  input         af_opt_0,
  input         af_opt_1,
  input         \af_plat_id[0] ,
  input         \af_plat_id[1] ,
  input         \af_plat_id[2] ,
  input         \af_plat_id[3] ,
  input         \af_plat_id[4] ,
  input         \af_plat_id[5] ,
  input         \af_plat_id[6] ,
  input         \af_plat_id[7]
);
endmodule

// ============================================================================
// Cells specific to ASSPR

(* blackbox *)
module qlal3_i2c_cell (
  input         arst,
  input         arstS,

  output        wb_ack,
  input  [ 2:0] wb_adr,
  input         wb_clk,
  input         wb_clkS,
  input         wb_cyc,
  input  [ 7:0] wb_dat_i,
  output [ 7:0] wb_dat_o,
  output        wb_inta,
  input         wb_rst,
  input         wb_rstS,
  input         wb_stb,
  input         wb_we,

  input         al_clr_i,
  output        al_o,
  input         al_stick_en_i,
  output        i2c_busy_o,
  input         rxack_clr_i,
  output        rxack_o,
  input         rxack_stick_en_i,
  output        tip_o,
  output        DrivingI2cBusOut,

  input         SCL_i,
  output        SCL_o,
  output        SCL_oen,
  input         SDA_i,
  output        SDA_o,
  output        SDA_oen
);
endmodule

