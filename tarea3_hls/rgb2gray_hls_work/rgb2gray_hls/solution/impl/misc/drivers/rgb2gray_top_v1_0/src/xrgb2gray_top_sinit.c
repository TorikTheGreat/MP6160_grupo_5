// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.1 (64-bit)
// Tool Version Limit: 2024.05
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef __linux__

#include "xstatus.h"
#ifdef SDT
#include "xparameters.h"
#endif
#include "xrgb2gray_top.h"

extern XRgb2gray_top_Config XRgb2gray_top_ConfigTable[];

#ifdef SDT
XRgb2gray_top_Config *XRgb2gray_top_LookupConfig(UINTPTR BaseAddress) {
	XRgb2gray_top_Config *ConfigPtr = NULL;

	int Index;

	for (Index = (u32)0x0; XRgb2gray_top_ConfigTable[Index].Name != NULL; Index++) {
		if (!BaseAddress || XRgb2gray_top_ConfigTable[Index].Control_BaseAddress == BaseAddress) {
			ConfigPtr = &XRgb2gray_top_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XRgb2gray_top_Initialize(XRgb2gray_top *InstancePtr, UINTPTR BaseAddress) {
	XRgb2gray_top_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XRgb2gray_top_LookupConfig(BaseAddress);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XRgb2gray_top_CfgInitialize(InstancePtr, ConfigPtr);
}
#else
XRgb2gray_top_Config *XRgb2gray_top_LookupConfig(u16 DeviceId) {
	XRgb2gray_top_Config *ConfigPtr = NULL;

	int Index;

	for (Index = 0; Index < XPAR_XRGB2GRAY_TOP_NUM_INSTANCES; Index++) {
		if (XRgb2gray_top_ConfigTable[Index].DeviceId == DeviceId) {
			ConfigPtr = &XRgb2gray_top_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XRgb2gray_top_Initialize(XRgb2gray_top *InstancePtr, u16 DeviceId) {
	XRgb2gray_top_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XRgb2gray_top_LookupConfig(DeviceId);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XRgb2gray_top_CfgInitialize(InstancePtr, ConfigPtr);
}
#endif

#endif

