yosys -import
if { [info procs selection_to_tcl_list] == {} } { plugin -i design_introspection }
yosys -import  ;# ingest plugin commands

proc selection_to_tcl_list_through_file { selection } {
    set file_name [test_output_path "[pid].txt"]
    select $selection -write $file_name
    set fh [open $file_name r]
    set result [list]
    while {[gets $fh line] >= 0} {
	lappend result $line
    }
    close $fh
    file delete $file_name
    return $result
}

proc test_selection { rfh selection } {
    if {[expr {[selection_to_tcl_list_through_file $selection] != [selection_to_tcl_list $selection]}]} {
    	puts "List from file: [selection_to_tcl_list_through_file $selection]"
    	puts "List in selection: [selection_to_tcl_list $selection]"
	error "Test with selection: $selection failed"
    } else {
	puts $rfh [selection_to_tcl_list $selection]
    }
}

read_verilog $::env(DESIGN_TOP).v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

# Test the selection command and write results to file
set rfh [open [test_output_path "selection_to_tcl_list.txt"] w]

set selection_tests [list "t:*" "w:*" "*"]
foreach test $selection_tests {
    test_selection $rfh $test
}

close $rfh
