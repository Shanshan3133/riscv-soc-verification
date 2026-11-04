# Volatile JTAG configuration only; does not program configuration flash.
# vivado -mode batch -source scripts/program_basys3.tcl -tclargs bitfile serial
set bitfile [file normalize [lindex $argv 0]]
set serial [lindex $argv 1]
if {![file exists $bitfile] || $serial eq ""} {error "Supply bitfile and board serial"}
open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet *$serial*]
if {[llength $targets] != 1} {error "Expected exactly one target for board $serial; got $targets"}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -quiet xc7a35t*]
if {[llength $devices] != 1} {error "Expected one Basys3 xc7a35t device; got $devices"}
set device [lindex $devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device $device
if {[get_property REGISTER.IR.BIT5_DONE $device] ne "1"} {error "FPGA DONE was not asserted"}
puts "PROGRAMMED_BOARD=$serial DEVICE=$device BITFILE=$bitfile"
report_property $device
close_hw_target
disconnect_hw_server
close_hw_manager
