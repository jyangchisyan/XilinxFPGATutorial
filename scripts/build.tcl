# Build firmware first with `make -C firmware`, then run this script in Vivado.
set root [file normalize [file join [file dirname [info script]] ..]]
set elf $root/build/firmware/app.elf
if {![file exists $elf]} {error "Run make -C firmware before building hardware"}
open_project $root/FPGAGetStartedAgain.xpr
open_bd_design $root/FPGAGetStartedAgain.srcs/sources_1/bd/system/system.bd
validate_bd_design
add_files -norecurse $elf
set_property SCOPED_TO_REF system [get_files $elf]
set_property SCOPED_TO_CELLS {microblaze_0} [get_files $elf]
set_property USED_IN_SIMULATION true [get_files $elf]
generate_target all [get_files system.bd]
set wrapper [make_wrapper -files [get_files system.bd] -top]
add_files -norecurse $wrapper
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
report_timing_summary -file $root/build/timing_summary.rpt
report_drc -file $root/build/drc.rpt
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] < 0} {error "Setup timing failed"}
if {[get_property SLACK [get_timing_paths -delay_type min -max_paths 1]] < 0} {error "Hold timing failed"}
file copy -force [get_property DIRECTORY [get_runs impl_1]]/system_wrapper.bit $root/build/system.bit
write_hw_platform -fixed -include_bit -force -file $root/build/system.xsa
close_project
