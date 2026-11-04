# vivado -mode batch -source scripts/build_vivado.tcl -tclargs arty35
set root [file normalize [file join [file dirname [info script]] ..]]
set board [lindex $argv 0]
switch $board {
 arty35 {set part xc7a35ticsg324-1L;set xdc arty_a7.xdc}
 arty100 {set part xc7a100tcsg324-1;set xdc arty_a7.xdc}
 basys3 {set part xc7a35tcpg236-1;set xdc basys3.xdc}
 default {error "Choose arty35, arty100, or basys3"}
}
set out [file join $root build $board]
file mkdir $out
create_project -force riscv_soc [file join $out project] -part $part
set sources [concat [glob $root/rtl/core/*.sv] [glob $root/rtl/periph/*.sv] [glob $root/rtl/soc/*.sv] [glob $root/rtl/debug/*.sv] [glob $root/rtl/board/*.sv]]
add_files $sources
add_files -fileset constrs_1 [file join $root constraints $xdc]
set_property top board_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -file [file join $out timing.rpt]
report_drc -file [file join $out drc.rpt]
report_cdc -file [file join $out cdc.rpt]
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_paths]==0 || [llength $hold_paths]==0} {error "No timing paths; inspect constraints"}
if {[get_property SLACK [lindex $setup_paths 0]]<0 || [get_property SLACK [lindex $hold_paths 0]]<0} {error "Timing failed; bitstream withheld"}
set drc_errors [get_drc_violations -filter {SEVERITY == Error}]
if {[llength $drc_errors]>0} {error "DRC errors; bitstream withheld"}
write_checkpoint -force [file join $out routed.dcp]
write_bitstream -force [file join $out riscv_soc.bit]
puts "Built $out/riscv_soc.bit; hardware has not been tested."
