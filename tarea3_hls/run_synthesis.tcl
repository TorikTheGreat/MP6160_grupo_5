#
# Vitis HLS Synthesis Script - RGB to Grayscale Accelerator
# Tool: vitis_hls
# Usage: vitis_hls -f run_synthesis.tcl
#

catch {::common::set_param -quiet hls.xocc.mode csynth};

# Copy source files to a temp directory (avoid path-with-spaces issues)
set script_dir [file normalize [file dirname [info script]]]
set src_dir $script_dir
set work_dir [file normalize "$script_dir/rgb2gray_hls_work"]
file mkdir $work_dir
cd $work_dir

open_project rgb2gray_hls
set_top rgb2gray_top

add_files "$src_dir/rgb2gray_kernel.cpp" -cflags "--std=c++14"
add_files -tb "$src_dir/tb_rgb2gray.cpp" -cflags "--std=c++14"

open_solution -flow_target vitis solution
set_part xcvc1902-vsva2197-2MP-e-S
create_clock -period 250MHz -name default

# Vitis HLS recommended config
config_dataflow -strict_mode warning
config_rtl -deadlock_detection sim
config_interface -m_axi_conservative_mode=1
config_interface -m_axi_addr64
config_interface -m_axi_auto_max_ports=0

config_export -format xo -ipname rgb2gray_top

csim_design -clean
csynth_design

close_project

puts "HLS completed successfully"
puts "Work directory: $work_dir"
exit
