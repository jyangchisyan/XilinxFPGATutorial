# Run from any directory: vivado -mode batch -source scripts/complete_system.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/build
open_project $root/FPGAGetStartedAgain.xpr
open_bd_design $root/FPGAGetStartedAgain.srcs/sources_1/bd/system/system.bd
if {[llength [get_bd_cells -quiet axi_interconnect_0]]} {
    error "System is already completed. Open the project, or run scripts/build.tcl."
}
file copy -force $root/FPGAGetStartedAgain.srcs/sources_1/bd/system/system.bd $root/build/system.before.bd
proc ip {name type props} {
    set c [create_bd_cell -type ip -vlnv xilinx.com:ip:$type $name]
    if {[llength $props]} {set_property -dict $props $c}
    return $c
}
proc wire {args} {set pins {}; foreach p $args {lappend pins [get_bd_pins $p]}; connect_bd_net {*}$pins}
proc bus {a b} {connect_bd_intf_net [get_bd_intf_pins $a] [get_bd_intf_pins $b]}

# The entire processor/AXI/LMB subsystem uses the MIG UI clock.
set_property -dict [list CONFIG.C_D_AXI 1 CONFIG.C_I_AXI 0 CONFIG.C_USE_ICACHE 0 CONFIG.C_USE_DCACHE 0 CONFIG.C_DEBUG_ENABLED 1 CONFIG.C_BASE_VECTORS 0x00000000] [get_bd_cells microblaze_0]
set_property -dict [list CONFIG.C_GPIO_WIDTH 1 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_IS_DUAL 0] [get_bd_cells axi_gpio_0]
ip axi_interconnect_0 axi_interconnect:2.1 [list CONFIG.NUM_SI 1 CONFIG.NUM_MI 2]
bus microblaze_0/M_AXI_DP axi_interconnect_0/S00_AXI
bus axi_interconnect_0/M00_AXI mig_7series_0/S_AXI
bus axi_interconnect_0/M01_AXI axi_gpio_0/S_AXI

# Separate instruction/data LMB controllers share one true dual-port BRAM.
foreach side {i d} {
    ip ${side}lmb lmb_v10:3.0 {}
    ip ${side}lmb_cntlr lmb_bram_if_cntlr:4.0 [list CONFIG.C_ECC 0]
    bus microblaze_0/[string toupper $side]LMB ${side}lmb/LMB_M
    bus ${side}lmb/LMB_Sl_0 ${side}lmb_cntlr/SLMB
}
ip boot_bram blk_mem_gen:8.4 [list CONFIG.Memory_Type True_Dual_Port_RAM CONFIG.use_bram_block BRAM_Controller CONFIG.Enable_B  Use_ENB_Pin]
bus ilmb_cntlr/BRAM_PORT boot_bram/BRAM_PORTA
bus dlmb_cntlr/BRAM_PORT boot_bram/BRAM_PORTB
ip mdm_0 mdm:3.2 [list CONFIG.C_USE_UART 0]
bus microblaze_0/DEBUG mdm_0/MBDEBUG_0
ip rst_ui proc_sys_reset:5.0 [list CONFIG.C_AUX_RESET_HIGH 1]
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports CPU_RESETN]
set_property CONFIG.USE_LOCKED true [get_bd_cells clk_wiz_0]
ip mig_reset_gate util_vector_logic:2.0 [list CONFIG.C_OPERATION and CONFIG.C_SIZE 1]
ip ready_gate util_vector_logic:2.0 [list CONFIG.C_OPERATION and CONFIG.C_SIZE 1]
ip zero xlconstant:1.1 [list CONFIG.CONST_VAL 0 CONFIG.CONST_WIDTH 1]

# Hold MIG reset until the 200 MHz reference is stable; never gate it with calibration.
disconnect_bd_net [get_bd_nets CPU_RESETN_1] [get_bd_pins mig_7series_0/sys_rst]
connect_bd_net [get_bd_ports CPU_RESETN] [get_bd_pins mig_reset_gate/Op1] [get_bd_pins rst_ui/ext_reset_in]
wire clk_wiz_0/locked mig_reset_gate/Op2
wire mig_reset_gate/Res mig_7series_0/sys_rst
wire mig_7series_0/mmcm_locked ready_gate/Op1
wire mig_7series_0/init_calib_complete ready_gate/Op2
wire ready_gate/Res rst_ui/dcm_locked
wire mig_7series_0/ui_clk_sync_rst rst_ui/aux_reset_in
wire mdm_0/Debug_SYS_Rst rst_ui/mb_debug_sys_rst
wire rst_ui/mb_reset microblaze_0/Reset
wire rst_ui/bus_struct_reset ilmb/SYS_Rst dlmb/SYS_Rst ilmb_cntlr/LMB_Rst dlmb_cntlr/LMB_Rst
wire rst_ui/interconnect_aresetn axi_interconnect_0/ARESETN
wire rst_ui/peripheral_aresetn axi_interconnect_0/S00_ARESETN axi_interconnect_0/M00_ARESETN axi_interconnect_0/M01_ARESETN mig_7series_0/aresetn axi_gpio_0/s_axi_aresetn
wire mig_7series_0/ui_clk microblaze_0/Clk ilmb/LMB_Clk dlmb/LMB_Clk ilmb_cntlr/LMB_Clk dlmb_cntlr/LMB_Clk rst_ui/slowest_sync_clk axi_interconnect_0/ACLK axi_interconnect_0/S00_ACLK axi_interconnect_0/M00_ACLK axi_interconnect_0/M01_ACLK axi_gpio_0/s_axi_aclk
wire zero/dout microblaze_0/Interrupt
delete_bd_objs [get_bd_ports ck_a0]
create_bd_port -dir O -from 0 -to 0 LED
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_ports LED]

create_bd_addr_seg -range 64K -offset 0x00000000 [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs ilmb_cntlr/SLMB/Mem] boot_instruction
create_bd_addr_seg -range 64K -offset 0x00000000 [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs dlmb_cntlr/SLMB/Mem] boot_data
create_bd_addr_seg -range 128M -offset 0x80000000 [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs mig_7series_0/memmap/memaddr] ddr2
create_bd_addr_seg -range 64K -offset 0x40000000 [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] gpio
validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
set wrapper [make_wrapper -files [get_files system.bd] -top]
add_files -norecurse $wrapper
set_property top system_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse $root/constraints/led.xdc
update_compile_order -fileset sources_1
write_hw_platform -fixed -force -file $root/build/system.xsa
close_project
