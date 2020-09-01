yosys -import
plugin -i selection

# Import the commands from the plugins to the tcl interpreter
yosys -import

proc selection_to_tcl_list_through_file { selection } {
    set file_name "[pid].txt"
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

read_verilog counter.v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

# Test the selection command and write results to file
set rfh [open counter.txt w]

set selection_tests [list "t:*" "w:*" "*"]
foreach test $selection_tests {
    test_selection $rfh $test
}

close $rfh
