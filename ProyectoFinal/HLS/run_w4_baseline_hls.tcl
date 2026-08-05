#
# Vitis HLS synthesis script for W4 FWHT baseline
#

catch {::common::set_param -quiet hls.xocc.mode csynth}

set top_name "wht_multiplier_forward"
set solution_name "solution_baseline"
set work_dir_name "w4_baseline_hls_work"

set script_dir [file normalize [file dirname [info script]]]
set project_root [file normalize "$script_dir/.."]
set baseline_dir [file normalize "$project_root/Baseline"]

set work_dir [file normalize "$script_dir/$work_dir_name"]
file mkdir $work_dir
cd $work_dir

open_project -reset w4_baseline_hls
set_top $top_name

add_files "$baseline_dir/wht_multiplier_baseline.cpp" \
    -cflags "-I$baseline_dir --std=c++17"

add_files -tb "$baseline_dir/wht_multiplier_baseline_tb.cpp" \
    -cflags "-I$baseline_dir --std=c++17"

open_solution -reset -flow_target vitis $solution_name

set_part xck26-sfvc784-2LV-c
create_clock -period 4 -name default

config_dataflow -strict_mode warning
config_rtl -deadlock_detection sim

csim_design -clean
csynth_design
cosim_design
export_design -format ip_catalog

set report_dir [file normalize \
    "$work_dir/w4_baseline_hls/$solution_name/syn/report"]

puts "W4 baseline HLS completed successfully"
puts "Reports at: $report_dir"

close_project
exit
