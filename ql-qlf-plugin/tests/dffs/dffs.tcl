yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

# =============================================================================
# qlf_k4n8

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k4n8/cells_sim.v synth_quicklogic -family qlf_k4n8 -top my_dff
synth_quicklogic -family qlf_k4n8 -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dffsr

# DFFR (posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffr_p
yosys cd my_dffr_p
stat
select -assert-count 1 t:dffsr
select -assert-count 1 t:\$lut

# DFFR (posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffr_p_2
yosys cd my_dffr_p_2
stat
select -assert-count 2 t:dffsr
select -assert-count 1 t:\$lut

# DFFR (negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffr_n
yosys cd my_dffr_n
stat
select -assert-count 1 t:dffsr

# DFFS (posedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffs_p
yosys cd my_dffs_p
stat
select -assert-count 1 t:dffsr
select -assert-count 1 t:\$lut

# DFFS (negedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffs_n
yosys cd my_dffs_n
stat
select -assert-count 1 t:dffsr

# DFFN
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffn
yosys cd my_dffn
stat
select -assert-count 1 t:dffnsr


# DFFNR (negedge CLK posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffnr_p
yosys cd my_dffnr_p
stat
select -assert-count 1 t:dffnsr
select -assert-count 1 t:\$lut

# DFFNR (negedge CLK negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffnr_n
yosys cd my_dffnr_n
stat
select -assert-count 1 t:dffnsr

# DFFNS (negedge CLK posedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffns_p
yosys cd my_dffns_p
stat
select -assert-count 1 t:dffnsr
select -assert-count 1 t:\$lut

# DFFS (negedge CLK negedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffns_n
yosys cd my_dffns_n
stat
select -assert-count 1 t:dffnsr

# DFFSR (posedge CLK posedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_ppp
yosys cd my_dffsr_ppp
stat
select -assert-count 1 t:dffsr
select -assert-count 2 t:\$lut

# DFFSR (posedge CLK negedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_pnp
yosys cd my_dffsr_pnp
stat
select -assert-count 1 t:dffsr
select -assert-count 2 t:\$lut

# DFFSR (posedge CLK posedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_ppn
yosys cd my_dffsr_ppn
stat
select -assert-count 1 t:dffsr
select -assert-count 1 t:\$lut

# DFFSR (posedge CLK negedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_pnn
yosys cd my_dffsr_pnn
stat
select -assert-count 1 t:dffsr
select -assert-count 1 t:\$lut

# DFFSR (negedge CLK posedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_npp
yosys cd my_dffsr_npp
stat
select -assert-count 1 t:dffnsr
select -assert-count 2 t:\$lut

# DFFSR (negedge CLK negedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_nnp
yosys cd my_dffsr_nnp
stat
select -assert-count 1 t:dffnsr
select -assert-count 2 t:\$lut

# DFFSR (negedge CLK posedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_npn
yosys cd my_dffsr_npn
stat
select -assert-count 1 t:dffnsr
select -assert-count 1 t:\$lut

# DFFSR (negedge CLK negedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffsr_nnn
yosys cd my_dffsr_nnn
stat
select -assert-count 1 t:dffnsr
select -assert-count 1 t:\$lut

design -reset

# =============================================================================
# qlf_k6n10

read_verilog $::env(DESIGN_TOP).v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k6n10/cells_sim.v synth_quicklogic -family qlf_k6n10 -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dff

# DFFR (posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffr_p
yosys cd my_dffr_p
stat
select -assert-count 1 t:dffr

# DFFR (posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffr_p_2
yosys cd my_dffr_p_2
stat
select -assert-count 2 t:dffr

# DFFR (negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffr_n
yosys cd my_dffr_n
stat
select -assert-count 1 t:dffr
select -assert-count 1 t:\$lut

#DFFRE (posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffre_p
yosys cd my_dffre_p
stat
select -assert-count 1 t:dffre

#DFFRE (negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffre_n
yosys cd my_dffre_n
stat
select -assert-count 1 t:dffre
select -assert-count 1 t:\$lut

# DFFS (posedge SET)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffs_p
yosys cd my_dffs_p
stat
select -assert-count 1 t:dffs

# DFFS (negedge SET)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffs_n
yosys cd my_dffs_n
stat
select -assert-count 1 t:dffs
select -assert-count 1 t:\$lut

# DFFSE (posedge SET)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffse_p
yosys cd my_dffse_p
stat
select -assert-count 1 t:dffse

# DFFSE (negedge SET)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffse_n
yosys cd my_dffse_n
stat
select -assert-count 1 t:dffse

# DFFN
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffn
yosys cd my_dffn
stat
select -assert-count 1 t:dff
select -assert-count 1 t:\$lut

# DFFNR (negedge CLK posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffnr_p
yosys cd my_dffnr_p
stat
select -assert-count 1 t:dffr
select -assert-count 1 t:\$lut

# DFFNR (negedge CLK negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffnr_n
yosys cd my_dffnr_n
stat
select -assert-count 1 t:dffr
select -assert-count 2 t:\$lut

# DFFNS (negedge CLK posedge SET)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffns_p
yosys cd my_dffns_p
stat
select -assert-count 1 t:dffs
select -assert-count 1 t:\$lut

# DFFS (negedge CLK negedge SET)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffns_n
yosys cd my_dffns_n
stat
select -assert-count 1 t:dffs
select -assert-count 2 t:\$lut

# DFFSR (posedge CLK posedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_ppp
yosys cd my_dffsr_ppp
stat
select -assert-count 1 t:dffsr
select -assert-count 1 t:\$lut

# DFFSR (posedge CLK negedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_pnp
yosys cd my_dffsr_pnp
stat
select -assert-count 1 t:dffsr
select -assert-count 1 t:\$lut

# DFFSR (posedge CLK posedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_ppn
yosys cd my_dffsr_ppn
stat
select -assert-count 1 t:dffsr
select -assert-count 2 t:\$lut

# DFFSR (posedge CLK negedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_pnn
yosys cd my_dffsr_pnn
stat
select -assert-count 1 t:dffsr
select -assert-count 2 t:\$lut

# DFFSR (negedge CLK posedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_npp
yosys cd my_dffsr_npp
stat
select -assert-count 1 t:dffsr
select -assert-count 2 t:\$lut

# DFFSR (negedge CLK negedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_nnp
yosys cd my_dffsr_nnp
stat
select -assert-count 1 t:dffsr
select -assert-count 2 t:\$lut

# DFFSR (negedge CLK posedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_npn
yosys cd my_dffsr_npn
stat
select -assert-count 1 t:dffsr
select -assert-count 3 t:\$lut

# DFFSR (negedge CLK negedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsr_nnn
yosys cd my_dffsr_nnn
stat
select -assert-count 1 t:dffsr
select -assert-count 3 t:\$lut

# DFFSRE (posedge CLK posedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_ppp
yosys cd my_dffsre_ppp
stat
select -assert-count 1 t:dffsre
select -assert-count 1 t:\$lut

# DFFSRE (posedge CLK negedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_pnp
yosys cd my_dffsre_pnp
stat
select -assert-count 1 t:dffsre
select -assert-count 1 t:\$lut

# DFFSRE (posedge CLK posedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_ppn
yosys cd my_dffsre_ppn
stat
select -assert-count 1 t:dffsre
select -assert-count 2 t:\$lut

# DFFSRE (posedge CLK negedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_pnn
yosys cd my_dffsre_pnn
stat
select -assert-count 1 t:dffsre
select -assert-count 2 t:\$lut

# DFFSRE (negedge CLK posedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_npp
yosys cd my_dffsre_npp
stat
select -assert-count 1 t:dffsre
select -assert-count 2 t:\$lut

# DFFSRE (negedge CLK negedge SET posedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_nnp
yosys cd my_dffsre_nnp
stat
select -assert-count 1 t:dffsre
select -assert-count 2 t:\$lut

# DFFSRE (negedge CLK posedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_npn
yosys cd my_dffsre_npn
stat
select -assert-count 1 t:dffsre
select -assert-count 3 t:\$lut

# DFFSRE (negedge CLK negedge SET negedge RST)
design -load read
synth_quicklogic -family qlf_k6n10 -top my_dffsre_nnn
yosys cd my_dffsre_nnn
stat
select -assert-count 1 t:dffsre
select -assert-count 3 t:\$lut

design -reset

# =============================================================================
# qlf_k6n10f

read_verilog $::env(DESIGN_TOP).v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:sdffsre

# DFFN
design -load read
hierarchy -top my_dffn
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffn
design -load postopt
yosys cd my_dffn
stat
select -assert-count 1 t:sdffnsre


# DFFSRE from DFFR_N
design -load read
hierarchy -top my_dffr_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffr_n
design -load postopt
yosys cd my_dffr_n
stat
select -assert-count 1 t:dffsre

# DFFSRE from DFFR_P
design -load read
hierarchy -top my_dffr_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffr_p
design -load postopt
yosys cd my_dffr_p
stat
select -assert-count 1 t:dffsre
select -assert-count 1 t:\$lut

# DFFSRE from DFFRE_N
design -load read
hierarchy -top my_dffre_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffre_n
design -load postopt
yosys cd my_dffre_n
stat
select -assert-count 1 t:dffsre

# DFFSRE from DFFRE_P
design -load read
hierarchy -top my_dffre_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffre_p
design -load postopt
yosys cd my_dffre_p
stat
select -assert-count 1 t:dffsre
select -assert-count 1 t:\$lut


# DFFSRE from DFFS_N
design -load read
hierarchy -top my_dffs_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffs_n
design -load postopt
yosys cd my_dffs_n
stat
select -assert-count 1 t:dffsre

# DFFSRE from DFFS_P
design -load read
hierarchy -top my_dffs_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffs_p
design -load postopt
yosys cd my_dffs_p
stat
select -assert-count 1 t:dffsre
select -assert-count 1 t:\$lut

# DFFSRE from DFFSE_N
design -load read
hierarchy -top my_dffse_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffse_n
design -load postopt
yosys cd my_dffse_n
stat
select -assert-count 1 t:dffsre

# DFFSRE from DFFSE_P
design -load read
hierarchy -top my_dffse_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_dffse_p
design -load postopt
yosys cd my_dffse_p
stat
select -assert-count 1 t:dffsre
select -assert-count 1 t:\$lut


# SDFFSRE from SDFFR_N
design -load read
hierarchy -top my_sdffr_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffr_n
design -load postopt
yosys cd my_sdffr_n
stat
select -assert-count 1 t:sdffsre

# SDFFSRE from SDFFR_P
design -load read
hierarchy -top my_sdffr_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffr_p
design -load postopt
yosys cd my_sdffr_p
stat
select -assert-count 1 t:sdffsre
select -assert-count 1 t:\$lut

# SDFFSRE from SDFFS_N
design -load read
hierarchy -top my_sdffs_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffs_n
design -load postopt
yosys cd my_sdffs_n
stat
select -assert-count 1 t:sdffsre

# SDFFSRE from SDFFS_P
design -load read
hierarchy -top my_sdffs_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffs_p
design -load postopt
yosys cd my_sdffs_p
stat
select -assert-count 1 t:sdffsre
select -assert-count 1 t:\$lut


# SDFFNSRE from SDFFNR_N
design -load read
hierarchy -top my_sdffnr_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffnr_n
design -load postopt
yosys cd my_sdffnr_n
stat
select -assert-count 1 t:sdffnsre

# SDFFNSRE from SDFFRN_P
design -load read
hierarchy -top my_sdffnr_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffnr_p
design -load postopt
yosys cd my_sdffnr_p
stat
select -assert-count 1 t:sdffnsre
select -assert-count 1 t:\$lut

# SDFFNSRE from SDFFNS_N
design -load read
hierarchy -top my_sdffns_n
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffns_n
design -load postopt
yosys cd my_sdffns_n
stat
select -assert-count 1 t:sdffnsre

# SDFFSRE from SDFFNS_P
design -load read
hierarchy -top my_sdffns_p
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_sdffns_p
design -load postopt
yosys cd my_sdffns_p
stat
select -assert-count 1 t:sdffnsre
select -assert-count 1 t:\$lut


# LATCH
design -load read
hierarchy -top my_latch
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latch
design -load postopt
yosys cd my_latch
stat
select -assert-count 1 t:latchsre

# LATCHN
design -load read
hierarchy -top my_latchn
yosys proc
equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchn
design -load postopt
yosys cd my_latchn
stat
select -assert-count 1 t:latchnsre


## LATCHSRE from LATCHR_N
#design -load read
#hierarchy -top my_latchr_n
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchr_n
#design -load postopt
#yosys cd my_latchr_n
#stat
#select -assert-count 1 t:latchr_n
#
## LATCHSRE from LATCHR_P
#design -load read
#hierarchy -top my_latchr_p
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchr_p
#design -load postopt
#yosys cd my_latchr_p
#stat
#select -assert-count 1 t:latchr_p
#select -assert-count 1 t:\$lut
#
## LATCHSRE from LATCHS_N
#design -load read
#hierarchy -top my_latchs_n
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchs_n
#design -load postopt
#yosys cd my_latchs_n
#stat
#select -assert-count 1 t:latchs_n
#
## LATCHSRE from LATCHS_P
#design -load read
#hierarchy -top my_latchs_p
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchs_p
#design -load postopt
#yosys cd my_latchs_p
#stat
#select -assert-count 1 t:latchs_p
#select -assert-count 1 t:\$lut
#
#
## LATCHSRE from LATCHNR_N
#design -load read
#hierarchy -top my_latchnr_n
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchnr_n
#design -load postopt
#yosys cd my_latchnr_n
#stat
#select -assert-count 1 t:latchnr_n
#
## LATCHSRE from LATCHNR_P
#design -load read
#hierarchy -top my_latchnr_p
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchnr_p
#design -load postopt
#yosys cd my_latchnr_p
#stat
#select -assert-count 1 t:latchnr_p
#select -assert-count 1 t:\$lut
#
## LATCHSRE from LATCHNS_N
#design -load read
#hierarchy -top my_latchns_n
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchns_n
#design -load postopt
#yosys cd my_latchns_n
#stat
#select -assert-count 1 t:latchns_n
#
## LATCHSRE from LATCHNS_P
#design -load read
#hierarchy -top my_latchns_p
#yosys proc
#equiv_opt -assert -async2sync -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f -top my_latchns_p
#design -load postopt
#yosys cd my_latchns_p
#stat
#select -assert-count 1 t:latchns_p
#select -assert-count 1 t:\$lut


design -reset

# =============================================================================

# DFF on pp3 device
design -reset

# DFF on pp3 device
read_verilog $::env(DESIGN_TOP).v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -async2sync -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3 -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dffepc
select -assert-count 1 t:ckpad
select -assert-count 1 t:inpad
select -assert-count 1 t:outpad
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1

# DFFE
design -load read
hierarchy -top my_dffe
yosys proc
equiv_opt -async2sync -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3 -top my_dffe
design -load postopt
yosys cd my_dffe
stat
select -assert-count 1 t:dffepc
select -assert-count 1 t:ckpad
select -assert-count 2 t:inpad
select -assert-count 1 t:outpad
select -assert-count 1 t:logic_0

# ADFF a.k.a. DFFR_P
design -load read
hierarchy -top my_dffr_p
yosys proc
equiv_opt -async2sync -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3 -top my_dffr_p
design -load postopt
yosys cd my_dffr_p
stat
select -assert-count 1 t:dffepc
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1
select -assert-count 1 t:inpad
select -assert-count 1 t:outpad
select -assert-count 2 t:ckpad

select -assert-none t:dffepc t:logic_0 t:logic_1 t:inpad t:outpad t:ckpad %% t:* %D

# ADFFN a.k.a. DFFR_N
design -load read
hierarchy -top my_dffr_n
yosys proc
equiv_opt -async2sync -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3 -top my_dffr_n
design -load postopt
yosys cd my_dffr_n
stat
select -assert-count 1 t:LUT1
select -assert-count 1 t:dffepc
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1
select -assert-count 2 t:inpad
select -assert-count 1 t:outpad
select -assert-count 1 t:ckpad

select -assert-none t:LUT1 t:dffepc t:logic_0 t:logic_1 t:inpad t:outpad t:ckpad %% t:* %D

# DFFS (posedge, sync set)
design -load read
hierarchy -top my_sdffs_p
yosys proc
equiv_opt -async2sync -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3 -top my_sdffs_p
design -load postopt
yosys cd my_sdffs_p
stat
select -assert-count 1 t:LUT2
select -assert-count 1 t:dffepc
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1
select -assert-count 2 t:inpad
select -assert-count 1 t:outpad
select -assert-count 1 t:ckpad

select -assert-none t:LUT2 t:dffepc t:logic_0 t:logic_1 t:inpad t:outpad t:ckpad %% t:* %D

# DFFS (negedge, sync reset)
design -load read
hierarchy -top my_sdffns_p
yosys proc
equiv_opt -async2sync -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3 -top my_sdffns_p
design -load postopt
yosys cd my_sdffns_p
stat
select -assert-count 1 t:LUT1
select -assert-count 1 t:LUT2
select -assert-count 1 t:dffepc
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1
select -assert-count 3 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT1 t:LUT2 t:dffepc t:logic_0 t:logic_1 t:inpad t:outpad t:ckpad %% t:* %D

