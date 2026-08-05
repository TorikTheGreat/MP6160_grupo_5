#
# Vivado post-HLS implementation script (non-project mode)
# Usage:
#   vivado -mode batch -source run_vivado_impl.tcl
#

set top_name "wht_multiplier_forward"
set solution_name "solution_baseline"
set hls_work_dir_name "w4_baseline_hls_work"
set vivado_out_dir_name "vivado_w4_baseline"

if {[info exists ::env(WHT_TOP)]} { set top_name $::env(WHT_TOP) }
if {[info exists ::env(WHT_SOL)]} { set solution_name $::env(WHT_SOL) }
if {[info exists ::env(WHT_DIR)]} { set hls_work_dir_name $::env(WHT_DIR) }
if {[info exists ::env(WHT_VIV_DIR)]} { set vivado_out_dir_name $::env(WHT_VIV_DIR) }

set script_dir [file normalize [file dirname [info script]]]
set rtl_dir [file normalize "$script_dir/$hls_work_dir_name/w4_baseline_hls/$solution_name/syn/verilog"]
set out_dir [file normalize "$script_dir/$vivado_out_dir_name"]

file mkdir $out_dir

set part_name xck26-sfvc784-2LV-c

# Reference clock only to enable timing analysis.
# Final fmax is extracted from post-route critical data path delay.
set analysis_clock_period_ns 10.000

puts "\[Vivado\] RTL dir: $rtl_dir"
puts "\[Vivado\] Output dir: $out_dir"

set rtl_files [glob -nocomplain "$rtl_dir/*.v"]
if {[llength $rtl_files] == 0} {
    puts "ERROR: No RTL files found in $rtl_dir"
    exit 1
}

create_project -in_memory -part $part_name
read_verilog $rtl_files
# Out-of-context flow avoids package IO placement constraints and is suitable
# for kernel-level post-route timing/resource estimation.
synth_design -mode out_of_context -top $top_name -part $part_name

if {[llength [get_ports ap_clk]] == 0} {
    puts "ERROR: ap_clk port not found in top module $top_name"
    exit 1
}

create_clock -period $analysis_clock_period_ns -name ap_clk [get_ports ap_clk]

opt_design
place_design
phys_opt_design
route_design

write_checkpoint -force "$out_dir/post_route.dcp"
report_utilization -file "$out_dir/utilization_post_route.rpt"
report_utilization -hierarchical -file "$out_dir/utilization_hier_post_route.rpt"
report_timing_summary -delay_type max -max_paths 10 -file "$out_dir/timing_post_route.rpt"
report_timing -delay_type max -max_paths 1 -file "$out_dir/timing_critical_path.rpt"

catch { report_utilization -json -file "$out_dir/utilization_post_route.json" }
catch { report_timing_summary -json -file "$out_dir/timing_post_route.json" }

set tp [get_timing_paths -max_paths 1 -delay_type max]
set wns [get_property SLACK $tp]
set dpd [get_property DATAPATH_DELAY $tp]

set summary_file [open "$out_dir/impl_summary.txt" w]
puts $summary_file "part=$part_name"
puts $summary_file "top=$top_name"
puts $summary_file "wns_ns=$wns"
puts $summary_file "datapath_delay_ns=$dpd"
close $summary_file

puts "\[Vivado\] Implementation completed"
puts "\[Vivado\] Reports at: $out_dir"
exit
