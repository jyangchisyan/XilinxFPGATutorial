# Program the volatile FPGA configuration over JTAG; does not write QSPI flash.
set root [file normalize [file join [file dirname [info script]] ..]]
set bit $root/build/system.bit
if {![file exists $bit]} {error "Missing bitstream: $bit. Build the project first."}
# Diagnose a restricted runtime before launching hw_server. No hardware is touched.
if {[catch {socket -server {apply {{channel address port} {close $channel}}} -myaddr 127.0.0.1 0} probe]} {
    error "Local TCP sockets are unavailable: $probe. hw_server requires local TCP access. Run this script from a host terminal outside the restricted execution environment."
}
close $probe
if {$::tcl_platform(os) eq "Linux" && ![file isdirectory /dev/bus/usb]} {
    error "USB device nodes are unavailable (/dev/bus/usb is missing). Run from a host terminal with USB/JTAG access."
}
open_hw_manager
if {[catch {connect_hw_server -allow_non_jtag} reason]} {
    error "Cannot connect to local hw_server: $reason. Run python3 scripts/check_jtag.py to inspect local TCP and USB access."
}
set targets [get_hw_targets -quiet]
if {[llength $targets] != 1} {
    error "Expected one JTAG target, found [llength $targets]: $targets. Connect only the intended board."
}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -quiet]
set matches {}
foreach dev $devices {
    if {[string match xc7a100t* [get_property PART $dev]]} {lappend matches $dev}
}
if {[llength $matches] != 1} {
    error "Expected one xc7a100t FPGA, found [llength $matches]. Devices: $devices"
}
set dev [lindex $matches 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device $dev
# Register property names vary by device/tool. Never query a nonexistent property.
set done_properties [lsearch -all -inline -regexp [list_property $dev] {^REGISTER\.(IR|CONFIG_STATUS)\..*[_\.]DONE$}]
set done_verified 0
foreach property $done_properties {
    set done [string toupper [string trim [get_property $property $dev]]]
    puts "FPGA_DONE_READBACK: $property=$done"
    if {$done in {0 FALSE LOW 0X0 0B0}} {error "FPGA DONE was not asserted: $property=$done"}
    if {$done in {1 TRUE HIGH 0X1 0B1}} {set done_verified 1}
}
puts "FPGA_PROGRAM_COMMAND_SUCCEEDED=1"
if {$done_verified} {
    puts "FPGA_PROGRAM_DONE=1"
} else {
    puts "WARNING: Programming command succeeded, but no supported readable DONE value was found. Independent DONE readback is unverified."
}
close_hw_target
disconnect_hw_server
close_hw_manager
