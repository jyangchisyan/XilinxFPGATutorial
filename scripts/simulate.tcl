set root [file normalize [file join [file dirname [info script]] ..]]
set elf $root/build/firmware/app.elf
if {![file exists $elf]} {error "Run make -C firmware first"}
set nm /tools/Xilinx/Vitis/2024.2/gnu/microblaze/lin/bin/mb-nm
if {[info exists ::env(MB_NM)]} {set nm $::env(MB_NM)}
if {![regexp -line {^([0-9a-fA-F]+) [A-Za-z] test_status$} [exec $nm $elf] -> addr]} {error "Missing test_status symbol"}
set f [open $root/build/firmware_symbols.vh w]
puts $f "localparam \[31:0\] STATUS_ADDR = 32'h$addr;"
close $f
create_project -force system_sim $root/build/simulation -part xc7a100tcsg324-1
set_property board_part digilentinc.com:nexys-a7-100t:part0:1.3 [current_project]
add_files -norecurse $root/FPGAGetStartedAgain.srcs/sources_1/bd/system/system.bd
open_bd_design [get_files system.bd]
validate_bd_design
generate_target all [get_files system.bd]
set wrapper [make_wrapper -files [get_files system.bd] -top]
add_files -norecurse $wrapper
set_property top system_wrapper [current_fileset]
add_files -norecurse $elf
set_property SCOPED_TO_REF system [get_files $elf]
set_property SCOPED_TO_CELLS {microblaze_0} [get_files $elf]
set model_dir $root/FPGAGetStartedAgain.gen/sources_1/bd/system/ip/system_mig_7series_0_0_1/system_mig_7series_0_0/example_design/sim
add_files -fileset sim_1 -norecurse [list $root/sim/system_tb.sv $model_dir/ddr2_model.v]
set_property include_dirs [list $root/build $model_dir] [get_filesets sim_1]
set_property top system_tb [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation
run all
set boots [get_value -radix unsigned /system_tb/boots]
if {$boots != 2} {error "Simulation failed: only $boots successful boots"}
close_sim
close_project
