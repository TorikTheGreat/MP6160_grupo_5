set moduleName load_rgb
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
set C_modelName {load_rgb}
set C_modelType { void 0 }
set ap_memory_interface_dict [dict create]
set C_modelArgList {
	{ image_in int 8 regular {pointer 0}  }
	{ stream_rgb int 24 regular {fifo 1 volatile }  }
	{ num_pixels int 32 regular  }
	{ num_pixels_c1 int 32 regular {fifo 1}  }
}
set hasAXIMCache 0
set hasAXIML2Cache 0
set AXIMCacheInstDict [dict create]
set C_modelArgMapList {[ 
	{ "Name" : "image_in", "interface" : "wire", "bitwidth" : 8, "direction" : "READONLY"} , 
 	{ "Name" : "stream_rgb", "interface" : "fifo", "bitwidth" : 24, "direction" : "WRITEONLY"} , 
 	{ "Name" : "num_pixels", "interface" : "wire", "bitwidth" : 32, "direction" : "READONLY"} , 
 	{ "Name" : "num_pixels_c1", "interface" : "fifo", "bitwidth" : 32, "direction" : "WRITEONLY"} ]}
# RTL Port declarations: 
set portNum 22
set portList { 
	{ ap_clk sc_in sc_logic 1 clock -1 } 
	{ ap_rst sc_in sc_logic 1 reset -1 active_high_sync } 
	{ ap_start sc_in sc_logic 1 start -1 } 
	{ start_full_n sc_in sc_logic 1 signal -1 } 
	{ ap_done sc_out sc_logic 1 predone -1 } 
	{ ap_continue sc_in sc_logic 1 continue -1 } 
	{ ap_idle sc_out sc_logic 1 done -1 } 
	{ ap_ready sc_out sc_logic 1 ready -1 } 
	{ start_out sc_out sc_logic 1 signal -1 } 
	{ start_write sc_out sc_logic 1 signal -1 } 
	{ image_in sc_in sc_lv 8 signal 0 } 
	{ stream_rgb_din sc_out sc_lv 24 signal 1 } 
	{ stream_rgb_num_data_valid sc_in sc_lv 5 signal 1 } 
	{ stream_rgb_fifo_cap sc_in sc_lv 5 signal 1 } 
	{ stream_rgb_full_n sc_in sc_logic 1 signal 1 } 
	{ stream_rgb_write sc_out sc_logic 1 signal 1 } 
	{ num_pixels sc_in sc_lv 32 signal 2 } 
	{ num_pixels_c1_din sc_out sc_lv 32 signal 3 } 
	{ num_pixels_c1_num_data_valid sc_in sc_lv 3 signal 3 } 
	{ num_pixels_c1_fifo_cap sc_in sc_lv 3 signal 3 } 
	{ num_pixels_c1_full_n sc_in sc_logic 1 signal 3 } 
	{ num_pixels_c1_write sc_out sc_logic 1 signal 3 } 
}
set NewPortList {[ 
	{ "name": "ap_clk", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "clock", "bundle":{"name": "ap_clk", "role": "default" }} , 
 	{ "name": "ap_rst", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "reset", "bundle":{"name": "ap_rst", "role": "default" }} , 
 	{ "name": "ap_start", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "start", "bundle":{"name": "ap_start", "role": "default" }} , 
 	{ "name": "start_full_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "start_full_n", "role": "default" }} , 
 	{ "name": "ap_done", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "predone", "bundle":{"name": "ap_done", "role": "default" }} , 
 	{ "name": "ap_continue", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "continue", "bundle":{"name": "ap_continue", "role": "default" }} , 
 	{ "name": "ap_idle", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "done", "bundle":{"name": "ap_idle", "role": "default" }} , 
 	{ "name": "ap_ready", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "ready", "bundle":{"name": "ap_ready", "role": "default" }} , 
 	{ "name": "start_out", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "start_out", "role": "default" }} , 
 	{ "name": "start_write", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "start_write", "role": "default" }} , 
 	{ "name": "image_in", "direction": "in", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "image_in", "role": "default" }} , 
 	{ "name": "stream_rgb_din", "direction": "out", "datatype": "sc_lv", "bitwidth":24, "type": "signal", "bundle":{"name": "stream_rgb", "role": "din" }} , 
 	{ "name": "stream_rgb_num_data_valid", "direction": "in", "datatype": "sc_lv", "bitwidth":5, "type": "signal", "bundle":{"name": "stream_rgb", "role": "num_data_valid" }} , 
 	{ "name": "stream_rgb_fifo_cap", "direction": "in", "datatype": "sc_lv", "bitwidth":5, "type": "signal", "bundle":{"name": "stream_rgb", "role": "fifo_cap" }} , 
 	{ "name": "stream_rgb_full_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_rgb", "role": "full_n" }} , 
 	{ "name": "stream_rgb_write", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_rgb", "role": "write" }} , 
 	{ "name": "num_pixels", "direction": "in", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "num_pixels", "role": "default" }} , 
 	{ "name": "num_pixels_c1_din", "direction": "out", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "num_pixels_c1", "role": "din" }} , 
 	{ "name": "num_pixels_c1_num_data_valid", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "num_pixels_c1", "role": "num_data_valid" }} , 
 	{ "name": "num_pixels_c1_fifo_cap", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "num_pixels_c1", "role": "fifo_cap" }} , 
 	{ "name": "num_pixels_c1_full_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "num_pixels_c1", "role": "full_n" }} , 
 	{ "name": "num_pixels_c1_write", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "num_pixels_c1", "role": "write" }}  ]}

set RtlHierarchyInfo {[
	{"ID" : "0", "Level" : "0", "Path" : "`AUTOTB_DUT_INST", "Parent" : "", "Child" : ["1"],
		"CDFG" : "load_rgb",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "1", "ap_idle" : "1", "real_start" : "1",
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
			{"Name" : "image_in", "Type" : "None", "Direction" : "I"},
			{"Name" : "stream_rgb", "Type" : "Fifo", "Direction" : "O", "DependentProc" : ["0"], "DependentChan" : "0", "DependentChanDepth" : "16", "DependentChanType" : "0",
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_load_rgb_Pipeline_load_loop_fu_60", "Port" : "stream_rgb", "Inst_start_state" : "2", "Inst_end_state" : "3"}]},
			{"Name" : "num_pixels", "Type" : "None", "Direction" : "I"},
			{"Name" : "num_pixels_c1", "Type" : "Fifo", "Direction" : "O", "DependentProc" : ["0"], "DependentChan" : "0", "DependentChanDepth" : "2", "DependentChanType" : "2",
				"BlockSignal" : [
					{"Name" : "num_pixels_c1_blk_n", "Type" : "RtlSignal"}]}]},
	{"ID" : "1", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.grp_load_rgb_Pipeline_load_loop_fu_60", "Parent" : "0", "Child" : ["2"],
		"CDFG" : "load_rgb_Pipeline_load_loop",
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
			{"Name" : "num_pixels", "Type" : "None", "Direction" : "I"},
			{"Name" : "or_ln20_3", "Type" : "None", "Direction" : "I"},
			{"Name" : "stream_rgb", "Type" : "Fifo", "Direction" : "O",
				"BlockSignal" : [
					{"Name" : "stream_rgb_blk_n", "Type" : "RtlSignal"}]}],
		"Loop" : [
			{"Name" : "load_loop", "PipelineType" : "UPC",
				"LoopDec" : {"FSMBitwidth" : "1", "FirstState" : "ap_ST_fsm_pp0_stage0", "FirstStateIter" : "ap_enable_reg_pp0_iter0", "FirstStateBlock" : "ap_block_pp0_stage0_subdone", "LastState" : "ap_ST_fsm_pp0_stage0", "LastStateIter" : "ap_enable_reg_pp0_iter1", "LastStateBlock" : "ap_block_pp0_stage0_subdone", "QuitState" : "ap_ST_fsm_pp0_stage0", "QuitStateIter" : "ap_enable_reg_pp0_iter1", "QuitStateBlock" : "ap_block_pp0_stage0_subdone", "OneDepthLoop" : "0", "has_ap_ctrl" : "1", "has_continue" : "0"}}]},
	{"ID" : "2", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_load_rgb_Pipeline_load_loop_fu_60.flow_control_loop_pipe_sequential_init_U", "Parent" : "1"}]}


set ArgLastReadFirstWriteLatency {
	load_rgb {
		image_in {Type I LastRead 0 FirstWrite -1}
		stream_rgb {Type O LastRead -1 FirstWrite 1}
		num_pixels {Type I LastRead 0 FirstWrite -1}
		num_pixels_c1 {Type O LastRead -1 FirstWrite 0}}
	load_rgb_Pipeline_load_loop {
		num_pixels {Type I LastRead 0 FirstWrite -1}
		or_ln20_3 {Type I LastRead 0 FirstWrite -1}
		stream_rgb {Type O LastRead -1 FirstWrite 1}}}

set hasDtUnsupportedChannel 0

set PerformanceInfo {[
	{"Name" : "Latency", "Min" : "-1", "Max" : "-1"}
	, {"Name" : "Interval", "Min" : "-1", "Max" : "-1"}
]}

set PipelineEnableSignalInfo {[
]}

set Spec2ImplPortList { 
	image_in { ap_none {  { image_in in_data 0 8 } } }
	stream_rgb { ap_fifo {  { stream_rgb_din fifo_data_in 1 24 }  { stream_rgb_num_data_valid fifo_status_num_data_valid 0 5 }  { stream_rgb_fifo_cap fifo_update 0 5 }  { stream_rgb_full_n fifo_status 0 1 }  { stream_rgb_write fifo_port_we 1 1 } } }
	num_pixels { ap_none {  { num_pixels in_data 0 32 } } }
	num_pixels_c1 { ap_fifo {  { num_pixels_c1_din fifo_data_in 1 32 }  { num_pixels_c1_num_data_valid fifo_status_num_data_valid 0 3 }  { num_pixels_c1_fifo_cap fifo_update 0 3 }  { num_pixels_c1_full_n fifo_status 0 1 }  { num_pixels_c1_write fifo_port_we 1 1 } } }
}
