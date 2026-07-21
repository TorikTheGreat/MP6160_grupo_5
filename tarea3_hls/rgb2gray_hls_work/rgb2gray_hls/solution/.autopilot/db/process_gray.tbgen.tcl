set moduleName process_gray
set isTopModule 0
set isCombinational 0
set isDatapathOnly 0
set isPipelined 0
set pipeline_type none
set FunctionProtocol ap_ctrl_hs
set isOneStateSeq 0
set ProfileFlag 0
set StallSigGenFlag 0
set isEnableWaveformDebug 1
set hasInterrupt 0
set DLRegFirstOffset 0
set DLRegItemOffset 0
set C_modelName {process_gray}
set C_modelType { void 0 }
set ap_memory_interface_dict [dict create]
set C_modelArgList {
	{ stream_rgb int 24 regular {fifo 0 volatile }  }
	{ stream_gray int 8 regular {fifo 1 volatile }  }
	{ num_pixels int 32 regular {fifo 0}  }
	{ num_pixels_c int 32 regular {fifo 1}  }
}
set hasAXIMCache 0
set hasAXIML2Cache 0
set AXIMCacheInstDict [dict create]
set C_modelArgMapList {[ 
	{ "Name" : "stream_rgb", "interface" : "fifo", "bitwidth" : 24, "direction" : "READONLY"} , 
 	{ "Name" : "stream_gray", "interface" : "fifo", "bitwidth" : 8, "direction" : "WRITEONLY"} , 
 	{ "Name" : "num_pixels", "interface" : "fifo", "bitwidth" : 32, "direction" : "READONLY"} , 
 	{ "Name" : "num_pixels_c", "interface" : "fifo", "bitwidth" : 32, "direction" : "WRITEONLY"} ]}
# RTL Port declarations: 
set portNum 27
set portList { 
	{ ap_clk sc_in sc_logic 1 clock -1 } 
	{ ap_rst sc_in sc_logic 1 reset -1 active_high_sync } 
	{ ap_start sc_in sc_logic 1 start -1 } 
	{ ap_done sc_out sc_logic 1 predone -1 } 
	{ ap_continue sc_in sc_logic 1 continue -1 } 
	{ ap_idle sc_out sc_logic 1 done -1 } 
	{ ap_ready sc_out sc_logic 1 ready -1 } 
	{ stream_rgb_dout sc_in sc_lv 24 signal 0 } 
	{ stream_rgb_num_data_valid sc_in sc_lv 5 signal 0 } 
	{ stream_rgb_fifo_cap sc_in sc_lv 5 signal 0 } 
	{ stream_rgb_empty_n sc_in sc_logic 1 signal 0 } 
	{ stream_rgb_read sc_out sc_logic 1 signal 0 } 
	{ stream_gray_din sc_out sc_lv 8 signal 1 } 
	{ stream_gray_num_data_valid sc_in sc_lv 5 signal 1 } 
	{ stream_gray_fifo_cap sc_in sc_lv 5 signal 1 } 
	{ stream_gray_full_n sc_in sc_logic 1 signal 1 } 
	{ stream_gray_write sc_out sc_logic 1 signal 1 } 
	{ num_pixels_dout sc_in sc_lv 32 signal 2 } 
	{ num_pixels_num_data_valid sc_in sc_lv 3 signal 2 } 
	{ num_pixels_fifo_cap sc_in sc_lv 3 signal 2 } 
	{ num_pixels_empty_n sc_in sc_logic 1 signal 2 } 
	{ num_pixels_read sc_out sc_logic 1 signal 2 } 
	{ num_pixels_c_din sc_out sc_lv 32 signal 3 } 
	{ num_pixels_c_num_data_valid sc_in sc_lv 3 signal 3 } 
	{ num_pixels_c_fifo_cap sc_in sc_lv 3 signal 3 } 
	{ num_pixels_c_full_n sc_in sc_logic 1 signal 3 } 
	{ num_pixels_c_write sc_out sc_logic 1 signal 3 } 
}
set NewPortList {[ 
	{ "name": "ap_clk", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "clock", "bundle":{"name": "ap_clk", "role": "default" }} , 
 	{ "name": "ap_rst", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "reset", "bundle":{"name": "ap_rst", "role": "default" }} , 
 	{ "name": "ap_start", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "start", "bundle":{"name": "ap_start", "role": "default" }} , 
 	{ "name": "ap_done", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "predone", "bundle":{"name": "ap_done", "role": "default" }} , 
 	{ "name": "ap_continue", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "continue", "bundle":{"name": "ap_continue", "role": "default" }} , 
 	{ "name": "ap_idle", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "done", "bundle":{"name": "ap_idle", "role": "default" }} , 
 	{ "name": "ap_ready", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "ready", "bundle":{"name": "ap_ready", "role": "default" }} , 
 	{ "name": "stream_rgb_dout", "direction": "in", "datatype": "sc_lv", "bitwidth":24, "type": "signal", "bundle":{"name": "stream_rgb", "role": "dout" }} , 
 	{ "name": "stream_rgb_num_data_valid", "direction": "in", "datatype": "sc_lv", "bitwidth":5, "type": "signal", "bundle":{"name": "stream_rgb", "role": "num_data_valid" }} , 
 	{ "name": "stream_rgb_fifo_cap", "direction": "in", "datatype": "sc_lv", "bitwidth":5, "type": "signal", "bundle":{"name": "stream_rgb", "role": "fifo_cap" }} , 
 	{ "name": "stream_rgb_empty_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_rgb", "role": "empty_n" }} , 
 	{ "name": "stream_rgb_read", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_rgb", "role": "read" }} , 
 	{ "name": "stream_gray_din", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "stream_gray", "role": "din" }} , 
 	{ "name": "stream_gray_num_data_valid", "direction": "in", "datatype": "sc_lv", "bitwidth":5, "type": "signal", "bundle":{"name": "stream_gray", "role": "num_data_valid" }} , 
 	{ "name": "stream_gray_fifo_cap", "direction": "in", "datatype": "sc_lv", "bitwidth":5, "type": "signal", "bundle":{"name": "stream_gray", "role": "fifo_cap" }} , 
 	{ "name": "stream_gray_full_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_gray", "role": "full_n" }} , 
 	{ "name": "stream_gray_write", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_gray", "role": "write" }} , 
 	{ "name": "num_pixels_dout", "direction": "in", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "num_pixels", "role": "dout" }} , 
 	{ "name": "num_pixels_num_data_valid", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "num_pixels", "role": "num_data_valid" }} , 
 	{ "name": "num_pixels_fifo_cap", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "num_pixels", "role": "fifo_cap" }} , 
 	{ "name": "num_pixels_empty_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "num_pixels", "role": "empty_n" }} , 
 	{ "name": "num_pixels_read", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "num_pixels", "role": "read" }} , 
 	{ "name": "num_pixels_c_din", "direction": "out", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "num_pixels_c", "role": "din" }} , 
 	{ "name": "num_pixels_c_num_data_valid", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "num_pixels_c", "role": "num_data_valid" }} , 
 	{ "name": "num_pixels_c_fifo_cap", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "num_pixels_c", "role": "fifo_cap" }} , 
 	{ "name": "num_pixels_c_full_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "num_pixels_c", "role": "full_n" }} , 
 	{ "name": "num_pixels_c_write", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "num_pixels_c", "role": "write" }}  ]}

set RtlHierarchyInfo {[
	{"ID" : "0", "Level" : "0", "Path" : "`AUTOTB_DUT_INST", "Parent" : "", "Child" : ["1"],
		"CDFG" : "process_gray",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "1", "ap_idle" : "1", "real_start" : "0",
		"Pipeline" : "None", "UnalignedPipeline" : "0", "RewindPipeline" : "0", "ProcessNetwork" : "0",
		"II" : "0",
		"VariableLatency" : "1", "ExactLatency" : "-1", "EstimateLatencyMin" : "-1", "EstimateLatencyMax" : "-1",
		"Combinational" : "0",
		"Datapath" : "0",
		"ClockEnable" : "0",
		"HasSubDataflow" : "0",
		"InDataflowNetwork" : "1",
		"HasNonBlockingOperation" : "0",
		"IsBlackBox" : "0",
		"Port" : [
			{"Name" : "stream_rgb", "Type" : "Fifo", "Direction" : "I", "DependentProc" : ["0"], "DependentChan" : "0", "DependentChanDepth" : "16", "DependentChanType" : "0",
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_process_gray_Pipeline_process_loop_fu_50", "Port" : "stream_rgb", "Inst_start_state" : "2", "Inst_end_state" : "3"}]},
			{"Name" : "stream_gray", "Type" : "Fifo", "Direction" : "O", "DependentProc" : ["0"], "DependentChan" : "0", "DependentChanDepth" : "16", "DependentChanType" : "0",
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_process_gray_Pipeline_process_loop_fu_50", "Port" : "stream_gray", "Inst_start_state" : "2", "Inst_end_state" : "3"}]},
			{"Name" : "num_pixels", "Type" : "Fifo", "Direction" : "I", "DependentProc" : ["0"], "DependentChan" : "0", "DependentChanDepth" : "2", "DependentChanType" : "2",
				"BlockSignal" : [
					{"Name" : "num_pixels_blk_n", "Type" : "RtlSignal"}]},
			{"Name" : "num_pixels_c", "Type" : "Fifo", "Direction" : "O", "DependentProc" : ["0"], "DependentChan" : "0", "DependentChanDepth" : "2", "DependentChanType" : "2",
				"BlockSignal" : [
					{"Name" : "num_pixels_c_blk_n", "Type" : "RtlSignal"}]}]},
	{"ID" : "1", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.grp_process_gray_Pipeline_process_loop_fu_50", "Parent" : "0", "Child" : ["2", "3", "4", "5", "6"],
		"CDFG" : "process_gray_Pipeline_process_loop",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "0", "ap_idle" : "1", "real_start" : "0",
		"Pipeline" : "None", "UnalignedPipeline" : "0", "RewindPipeline" : "0", "ProcessNetwork" : "0",
		"II" : "0",
		"VariableLatency" : "1", "ExactLatency" : "-1", "EstimateLatencyMin" : "-1", "EstimateLatencyMax" : "-1",
		"Combinational" : "0",
		"Datapath" : "0",
		"ClockEnable" : "0",
		"HasSubDataflow" : "0",
		"InDataflowNetwork" : "0",
		"HasNonBlockingOperation" : "0",
		"IsBlackBox" : "0",
		"Port" : [
			{"Name" : "num_pixels_load", "Type" : "None", "Direction" : "I"},
			{"Name" : "stream_rgb", "Type" : "Fifo", "Direction" : "I",
				"BlockSignal" : [
					{"Name" : "stream_rgb_blk_n", "Type" : "RtlSignal"}]},
			{"Name" : "stream_gray", "Type" : "Fifo", "Direction" : "O",
				"BlockSignal" : [
					{"Name" : "stream_gray_blk_n", "Type" : "RtlSignal"}]}],
		"Loop" : [
			{"Name" : "process_loop", "PipelineType" : "UPC",
				"LoopDec" : {"FSMBitwidth" : "1", "FirstState" : "ap_ST_fsm_pp0_stage0", "FirstStateIter" : "ap_enable_reg_pp0_iter0", "FirstStateBlock" : "ap_block_pp0_stage0_subdone", "LastState" : "ap_ST_fsm_pp0_stage0", "LastStateIter" : "ap_enable_reg_pp0_iter7", "LastStateBlock" : "ap_block_pp0_stage0_subdone", "QuitState" : "ap_ST_fsm_pp0_stage0", "QuitStateIter" : "ap_enable_reg_pp0_iter7", "QuitStateBlock" : "ap_block_pp0_stage0_subdone", "OneDepthLoop" : "0", "has_ap_ctrl" : "1", "has_continue" : "0"}}]},
	{"ID" : "2", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_process_gray_Pipeline_process_loop_fu_50.mul_8ns_14ns_21_1_1_U11", "Parent" : "1"},
	{"ID" : "3", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_process_gray_Pipeline_process_loop_fu_50.mac_muladd_12ns_8ns_21ns_22_4_1_U12", "Parent" : "1"},
	{"ID" : "4", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_process_gray_Pipeline_process_loop_fu_50.mac_muladd_10ns_8ns_13ns_18_4_1_U13", "Parent" : "1"},
	{"ID" : "5", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_process_gray_Pipeline_process_loop_fu_50.am_addmul_18ns_22ns_23ns_45_4_1_U14", "Parent" : "1"},
	{"ID" : "6", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_process_gray_Pipeline_process_loop_fu_50.flow_control_loop_pipe_sequential_init_U", "Parent" : "1"}]}


set ArgLastReadFirstWriteLatency {
	process_gray {
		stream_rgb {Type I LastRead 1 FirstWrite -1}
		stream_gray {Type O LastRead -1 FirstWrite 7}
		num_pixels {Type I LastRead 0 FirstWrite -1}
		num_pixels_c {Type O LastRead -1 FirstWrite 0}}
	process_gray_Pipeline_process_loop {
		num_pixels_load {Type I LastRead 0 FirstWrite -1}
		stream_rgb {Type I LastRead 1 FirstWrite -1}
		stream_gray {Type O LastRead -1 FirstWrite 7}}}

set hasDtUnsupportedChannel 0

set PerformanceInfo {[
	{"Name" : "Latency", "Min" : "-1", "Max" : "-1"}
	, {"Name" : "Interval", "Min" : "-1", "Max" : "-1"}
]}

set PipelineEnableSignalInfo {[
]}

set Spec2ImplPortList { 
	stream_rgb { ap_fifo {  { stream_rgb_dout fifo_data_in 0 24 }  { stream_rgb_num_data_valid fifo_status_num_data_valid 0 5 }  { stream_rgb_fifo_cap fifo_update 0 5 }  { stream_rgb_empty_n fifo_status 0 1 }  { stream_rgb_read fifo_port_we 1 1 } } }
	stream_gray { ap_fifo {  { stream_gray_din fifo_data_in 1 8 }  { stream_gray_num_data_valid fifo_status_num_data_valid 0 5 }  { stream_gray_fifo_cap fifo_update 0 5 }  { stream_gray_full_n fifo_status 0 1 }  { stream_gray_write fifo_port_we 1 1 } } }
	num_pixels { ap_fifo {  { num_pixels_dout fifo_data_in 0 32 }  { num_pixels_num_data_valid fifo_status_num_data_valid 0 3 }  { num_pixels_fifo_cap fifo_update 0 3 }  { num_pixels_empty_n fifo_status 0 1 }  { num_pixels_read fifo_port_we 1 1 } } }
	num_pixels_c { ap_fifo {  { num_pixels_c_din fifo_data_in 1 32 }  { num_pixels_c_num_data_valid fifo_status_num_data_valid 0 3 }  { num_pixels_c_fifo_cap fifo_update 0 3 }  { num_pixels_c_full_n fifo_status 0 1 }  { num_pixels_c_write fifo_port_we 1 1 } } }
}
