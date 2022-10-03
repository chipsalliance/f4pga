yosys -import
if { [info procs get_count] == {} } { plugin -i design_introspection }
yosys -import # ingest new plugin commands

read_verilog -icells $::env(DESIGN_TOP).v
hierarchy -auto-top

set n [get_count -modules my_gate]
puts "Module count: $n"
if {$n != "1"} {
    error "Invalid count"
}

set n [get_count -cells t:\$_BUF_]
puts "BUF count: $n"
if {$n != "4"} {
    error "Invalid count"
}

set n [get_count -cells t:\$_NOT_]
puts "NOT count: $n"
if {$n != "3"} {
    error "Invalid count"
}

set n [get_count -wires w:*]
puts "Wire count: $n"
if {$n != "5"} {
    error "Invalid count"
}

