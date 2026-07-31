#
# Vitis HLS synthesis script for W2 (WHT lossless core)
# Usage:
#   vitis_hls -f run_w2_hls.tcl
#

catch {::common::set_param -quiet hls.xocc.mode csynth}

set script_dir [file normalize [file dirname [info script]]]
set project_root [file normalize "$script_dir/.."]
set src_dir [file normalize "$project_root/Source"]
set tb_dir [file normalize "$project_root/TB"]

# Keep all generated files local to W2/
set work_dir [file normalize "$script_dir/wht_hls_work"]
file mkdir $work_dir
cd $work_dir

open_project -reset wht_hls
set_top wht_lossless_core

add_files "$src_dir/wht_core.cpp" -cflags "-I$src_dir --std=c++17"
add_files -tb "$tb_dir/wht_core_tb.cpp" -cflags "-I$src_dir --std=c++17"

open_solution -reset -flow_target vitis solution_kv260
set_part xcvc1902-vsva2197-2MP-e-S
create_clock -period 4 -name default

# Conservative HLS defaults similar to your functional T3 flow
config_dataflow -strict_mode warning
config_rtl -deadlock_detection sim

# Run C simulation + synthesis (required for W2 metrics)
csim_design -clean
csynth_design

# Export IP for downstream Vivado integration
export_design -format ip_catalog

set report_dir [file normalize "$work_dir/wht_hls/solution_kv260/syn/report"]
puts "W2 HLS completed successfully"
puts "Reports at: $report_dir"
close_project
exit
