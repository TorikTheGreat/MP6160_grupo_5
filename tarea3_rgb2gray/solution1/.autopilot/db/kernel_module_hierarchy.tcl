set ModuleHierarchy {[{
"Name" : "rgb2gray_top","ID" : "0","Type" : "dataflow",
"SubInsts" : [
	{"Name" : "load_rgb_U0","ID" : "1","Type" : "sequential",
		"SubInsts" : [
		{"Name" : "grp_load_rgb_Pipeline_load_loop_fu_60","ID" : "2","Type" : "sequential",
			"SubLoops" : [
			{"Name" : "load_loop","ID" : "3","Type" : "pipeline"},]},]},
	{"Name" : "process_gray_U0","ID" : "4","Type" : "sequential",
		"SubInsts" : [
		{"Name" : "grp_process_gray_Pipeline_process_loop_fu_50","ID" : "5","Type" : "sequential",
			"SubLoops" : [
			{"Name" : "process_loop","ID" : "6","Type" : "pipeline"},]},]},
	{"Name" : "store_gray_U0","ID" : "7","Type" : "sequential",
		"SubInsts" : [
		{"Name" : "grp_store_gray_Pipeline_store_loop_fu_53","ID" : "8","Type" : "sequential",
			"SubLoops" : [
			{"Name" : "store_loop","ID" : "9","Type" : "pipeline"},]},]},]
}]}