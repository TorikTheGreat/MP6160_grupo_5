############################################################
## This file is generated automatically by Vitis HLS.
## Please DO NOT edit it.
## Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
## Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
############################################################
open_project tarea3_rgb2gray
set_top rgb2gray_top
add_files tarea3_rgb2gray/rgb2gray_kernel.cpp
add_files tarea3_rgb2gray/rgb2gray_kernel.h
add_files -tb tarea3_rgb2gray/tb_kernel.cpp
open_solution "solution1" -flow_target vivado
set_part {xck26-sfvc784-2LV-c}
create_clock -period 4 -name default
#source "./tarea3_rgb2gray/solution1/directives.tcl"
csim_design
csynth_design
cosim_design
export_design -format ip_catalog
