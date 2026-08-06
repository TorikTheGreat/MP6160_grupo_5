# Generic Vivado out-of-context implementation flow.
# Required environment variables:
#   WHT_TOP, WHT_RTL_DIR, WHT_REPORT_DIR
# Optional:
#   WHT_PART, WHT_VIVADO_CLOCK_NS

proc require_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        puts "ERROR: Missing required environment variable $name"
        exit 2
    }
    return $::env($name)
}

set top_name [require_env WHT_TOP]
set rtl_dir [file normalize [require_env WHT_RTL_DIR]]
set report_dir [file normalize [require_env WHT_REPORT_DIR]]
set part_name [expr {[info exists ::env(WHT_PART)] ? $::env(WHT_PART) : "xck26-sfvc784-2LV-c"}]
set requested_period_ns [expr {[info exists ::env(WHT_VIVADO_CLOCK_NS)] ? $::env(WHT_VIVADO_CLOCK_NS) : "10.0"}]

file mkdir $report_dir

set rtl_files [concat \
    [glob -nocomplain "$rtl_dir/*.v"] \
    [glob -nocomplain "$rtl_dir/*.sv"]]

if {[llength $rtl_files] == 0} {
    puts "ERROR: No RTL files found in $rtl_dir"
    exit 2
}

puts "============================================================"
puts "Vivado configurable implementation"
puts "  top        : $top_name"
puts "  RTL dir    : $rtl_dir"
puts "  report dir : $report_dir"
puts "  part       : $part_name"
puts "  clock ns   : $requested_period_ns"
puts "============================================================"

create_project -in_memory -part $part_name
read_verilog $rtl_files
synth_design -mode out_of_context -top $top_name -part $part_name

if {[llength [get_ports ap_clk]] == 0} {
    puts "ERROR: ap_clk port not found in top module $top_name"
    exit 2
}

create_clock -period $requested_period_ns -name ap_clk [get_ports ap_clk]

opt_design
place_design
phys_opt_design
route_design

write_checkpoint -force "$report_dir/post_route.dcp"
report_utilization -file "$report_dir/utilization_post_route.rpt"
report_utilization -hierarchical -file "$report_dir/utilization_hier_post_route.rpt"
report_timing_summary -delay_type max -max_paths 20 -file "$report_dir/timing_post_route.rpt"
report_timing -delay_type max -max_paths 1 -file "$report_dir/timing_critical_path.rpt"
catch {report_power -file "$report_dir/power_post_route.rpt"}
catch {report_methodology -file "$report_dir/methodology_post_route.rpt"}
catch {report_utilization -json -file "$report_dir/utilization_post_route.json"}
catch {report_timing_summary -json -file "$report_dir/timing_post_route.json"}

set timing_paths [get_timing_paths -max_paths 1 -delay_type max]
set wns "N/A"
set datapath "N/A"
if {[llength $timing_paths] > 0} {
    set wns [get_property SLACK $timing_paths]
    set datapath [get_property DATAPATH_DELAY $timing_paths]
}

set achieved_period "N/A"
set extrapolated_freq "N/A"
if {$wns ne "N/A"} {
    set achieved_period [expr {double($requested_period_ns) - double($wns)}]
    if {$achieved_period > 0.0} {
        set extrapolated_freq [expr {1000.0 / $achieved_period}]
    }
}

set route_status "N/A"
catch {set route_status [get_property ROUTE_STATUS [current_design]]}
set summary_file [open "$report_dir/impl_summary.txt" w]
puts $summary_file "part=$part_name"
puts $summary_file "top=$top_name"
puts $summary_file "requested_period_ns=$requested_period_ns"
puts $summary_file "wns_ns=$wns"
puts $summary_file "datapath_delay_ns=$datapath"
puts $summary_file "wns_extrapolated_period_ns=$achieved_period"
puts $summary_file "wns_extrapolated_frequency_mhz=$extrapolated_freq"
puts $summary_file "route_status=$route_status"
close $summary_file

puts "Vivado implementation completed"
puts "Reports at: $report_dir"
exit 0
