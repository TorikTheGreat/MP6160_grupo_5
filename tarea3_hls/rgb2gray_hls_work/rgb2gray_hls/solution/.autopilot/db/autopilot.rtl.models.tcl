set SynModuleInfo {
  {SRCNAME entry_proc MODELNAME entry_proc RTLNAME rgb2gray_top_entry_proc}
  {SRCNAME load_rgb MODELNAME load_rgb RTLNAME rgb2gray_top_load_rgb}
  {SRCNAME process_gray_Pipeline_process_loop MODELNAME process_gray_Pipeline_process_loop RTLNAME rgb2gray_top_process_gray_Pipeline_process_loop
    SUBMODULES {
      {MODELNAME rgb2gray_top_mul_8ns_14ns_21_1_1 RTLNAME rgb2gray_top_mul_8ns_14ns_21_1_1 BINDTYPE op TYPE mul IMPL auto LATENCY 0 ALLOW_PRAGMA 1}
      {MODELNAME rgb2gray_top_mac_muladd_12ns_8ns_21ns_22_4_1 RTLNAME rgb2gray_top_mac_muladd_12ns_8ns_21ns_22_4_1 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
      {MODELNAME rgb2gray_top_mac_muladd_10ns_8ns_13ns_18_4_1 RTLNAME rgb2gray_top_mac_muladd_10ns_8ns_13ns_18_4_1 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
      {MODELNAME rgb2gray_top_am_addmul_18ns_22ns_23ns_45_4_1 RTLNAME rgb2gray_top_am_addmul_18ns_22ns_23ns_45_4_1 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
      {MODELNAME rgb2gray_top_flow_control_loop_pipe_sequential_init RTLNAME rgb2gray_top_flow_control_loop_pipe_sequential_init BINDTYPE interface TYPE internal_upc_flow_control INSTNAME rgb2gray_top_flow_control_loop_pipe_sequential_init_U}
    }
  }
  {SRCNAME process_gray MODELNAME process_gray RTLNAME rgb2gray_top_process_gray}
  {SRCNAME store_gray MODELNAME store_gray RTLNAME rgb2gray_top_store_gray}
  {SRCNAME rgb2gray_top MODELNAME rgb2gray_top RTLNAME rgb2gray_top IS_TOP 1
    SUBMODULES {
      {MODELNAME rgb2gray_top_fifo_w64_d4_S RTLNAME rgb2gray_top_fifo_w64_d4_S BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME m_axi_out_c_U}
      {MODELNAME rgb2gray_top_fifo_w32_d4_S RTLNAME rgb2gray_top_fifo_w32_d4_S BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME addr_out_c_U}
      {MODELNAME rgb2gray_top_fifo_w24_d16_S RTLNAME rgb2gray_top_fifo_w24_d16_S BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME stream_rgb_U}
      {MODELNAME rgb2gray_top_fifo_w32_d2_S RTLNAME rgb2gray_top_fifo_w32_d2_S BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME num_pixels_c1_U}
      {MODELNAME rgb2gray_top_fifo_w8_d16_S RTLNAME rgb2gray_top_fifo_w8_d16_S BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME stream_gray_U}
      {MODELNAME rgb2gray_top_fifo_w32_d2_S RTLNAME rgb2gray_top_fifo_w32_d2_S BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME num_pixels_c_U}
      {MODELNAME rgb2gray_top_start_for_store_gray_U0 RTLNAME rgb2gray_top_start_for_store_gray_U0 BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME start_for_store_gray_U0_U}
      {MODELNAME rgb2gray_top_start_for_process_gray_U0 RTLNAME rgb2gray_top_start_for_process_gray_U0 BINDTYPE storage TYPE fifo IMPL srl ALLOW_PRAGMA 1 INSTNAME start_for_process_gray_U0_U}
      {MODELNAME rgb2gray_top_gmem_in_m_axi RTLNAME rgb2gray_top_gmem_in_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME rgb2gray_top_gmem_out_m_axi RTLNAME rgb2gray_top_gmem_out_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME rgb2gray_top_control_s_axi RTLNAME rgb2gray_top_control_s_axi BINDTYPE interface TYPE interface_s_axilite}
    }
  }
}
