f4pga value     top
f4pga value     part_name
f4pga take      build_dir
f4pga take      sources
f4pga produce   json                  ${f4pga_build_dir}/${f4pga_top}.json             -meta "Yosys JSON netlist"
