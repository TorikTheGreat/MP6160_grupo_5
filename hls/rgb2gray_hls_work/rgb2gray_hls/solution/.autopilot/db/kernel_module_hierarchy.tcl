set ModuleHierarchy {[{
"Name" : "rgb2gray_top","ID" : "0","Type" : "dataflow",
"SubInsts" : [
	{"Name" : "entry_proc_U0","ID" : "1","Type" : "sequential"},
	{"Name" : "load_rgb_U0","ID" : "2","Type" : "pipeline",
		"SubLoops" : [
		{"Name" : "load_loop","ID" : "3","Type" : "pipeline"},]},
	{"Name" : "process_gray_U0","ID" : "4","Type" : "sequential",
		"SubInsts" : [
		{"Name" : "grp_process_gray_Pipeline_process_loop_fu_50","ID" : "5","Type" : "sequential",
			"SubLoops" : [
			{"Name" : "process_loop","ID" : "6","Type" : "pipeline"},]},]},
	{"Name" : "store_gray_U0","ID" : "7","Type" : "pipeline",
		"SubLoops" : [
		{"Name" : "store_loop","ID" : "8","Type" : "pipeline"},]},]
}]}