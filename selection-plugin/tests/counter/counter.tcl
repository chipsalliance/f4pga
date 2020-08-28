yosys -import
plugin -i selection

# Import the commands from the plugins to the tcl interpreter
yosys -import

proc selection_to_tcl_list_through_file { expression } {
    set file_name "[pid].txt"
    select $expression -write $file_name
    set fh [open $file_name r]
    set result [list]
    while {[gets $fh line] >= 0} {
	lappend result $line
    }
    close $fh
    file delete $file_name
    return $result
}

proc test_selection { expression {debug 0} } {
    if {$debug} {
    	puts "List from file: [selection_to_tcl_list_through_file $expression]"
    	puts "List in selection: [selection_to_tcl_list $expression]"
    }
    return [expr {[selection_to_tcl_list_through_file $expression] == [selection_to_tcl_list $expression]}]
}

read_verilog counter.v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

# Test the selection command and write results to file
set rfh [open counter.txt w]

puts $rfh [test_selection "t:*"]
puts $rfh [test_selection "w:*"]
puts $rfh [test_selection "*"]

close $rfh
