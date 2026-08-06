# Generic Vitis HLS flow for all WHT variants.
# Required environment variables:
#   WHT_TOP, WHT_SOURCE, WHT_TB, WHT_PROJECT, WHT_SOLUTION, WHT_WORK_DIR
# Optional:
#   WHT_PART, WHT_HLS_CLOCK_NS, WHT_RUN_COSIM (1/0)

proc require_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        puts "ERROR: Missing required environment variable $name"
        exit 2
    }
    return $::env($name)
}

proc bool_env {name default_value} {
    if {![info exists ::env($name)]} {
        return $default_value
    }
    set value [string tolower $::env($name)]
    return [expr {$value in {1 true yes on}}]
}

catch {::common::set_param -quiet hls.xocc.mode csynth}

set script_dir [file normalize [file dirname [info script]]]
set top_name [require_env WHT_TOP]
set source_file [file normalize "$script_dir/[require_env WHT_SOURCE]"]
set tb_file [file normalize "$script_dir/[require_env WHT_TB]"]
set project_name [require_env WHT_PROJECT]
set solution_name [require_env WHT_SOLUTION]
set work_dir [file normalize [require_env WHT_WORK_DIR]]
set part_name [expr {[info exists ::env(WHT_PART)] ? $::env(WHT_PART) : "xck26-sfvc784-2LV-c"}]
set hls_clock_ns [expr {[info exists ::env(WHT_HLS_CLOCK_NS)] ? $::env(WHT_HLS_CLOCK_NS) : "4.0"}]
set run_cosim [bool_env WHT_RUN_COSIM 1]

if {![file exists $source_file]} {
    puts "ERROR: Source file not found: $source_file"
    exit 2
}
if {![file exists $tb_file]} {
    puts "ERROR: Testbench file not found: $tb_file"
    exit 2
}

file mkdir $work_dir
cd $work_dir

puts "============================================================"
puts "Vitis HLS configurable run"
puts "  top       : $top_name"
puts "  source    : $source_file"
puts "  testbench : $tb_file"
puts "  project   : $project_name"
puts "  solution  : $solution_name"
puts "  part      : $part_name"
puts "  clock ns  : $hls_clock_ns"
puts "  cosim     : $run_cosim"
puts "============================================================"

open_project -reset $project_name
set_top $top_name

set include_flags "-I[file dirname $source_file] -I[file dirname $tb_file] -I[file normalize $script_dir/../Source] -I[file normalize $script_dir/../Baseline] --std=c++17"
add_files $source_file -cflags $include_flags
add_files -tb $tb_file -cflags $include_flags

open_solution -reset -flow_target vitis $solution_name
set_part $part_name
create_clock -period $hls_clock_ns -name default

config_dataflow -strict_mode warning
config_rtl -deadlock_detection sim

csim_design -clean
csynth_design
if {$run_cosim} {
    cosim_design -rtl verilog -tool xsim
}
export_design -format ip_catalog

set solution_dir [file normalize "$work_dir/$project_name/$solution_name"]
puts "HLS completed successfully"
puts "Solution directory: $solution_dir"
close_project
exit 0
