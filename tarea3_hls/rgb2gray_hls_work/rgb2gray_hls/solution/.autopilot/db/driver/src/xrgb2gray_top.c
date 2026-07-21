// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.1 (64-bit)
// Tool Version Limit: 2024.05
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
/***************************** Include Files *********************************/
#include "xrgb2gray_top.h"

/************************** Function Implementation *************************/
#ifndef __linux__
int XRgb2gray_top_CfgInitialize(XRgb2gray_top *InstancePtr, XRgb2gray_top_Config *ConfigPtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(ConfigPtr != NULL);

    InstancePtr->Control_BaseAddress = ConfigPtr->Control_BaseAddress;
    InstancePtr->IsReady = XIL_COMPONENT_IS_READY;

    return XST_SUCCESS;
}
#endif

void XRgb2gray_top_Start(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL) & 0x80;
    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL, Data | 0x01);
}

u32 XRgb2gray_top_IsDone(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL);
    return (Data >> 1) & 0x1;
}

u32 XRgb2gray_top_IsIdle(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL);
    return (Data >> 2) & 0x1;
}

u32 XRgb2gray_top_IsReady(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL);
    // check ap_start to see if the pcore is ready for next input
    return !(Data & 0x1);
}

void XRgb2gray_top_Continue(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL) & 0x80;
    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL, Data | 0x10);
}

void XRgb2gray_top_EnableAutoRestart(XRgb2gray_top *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL, 0x80);
}

void XRgb2gray_top_DisableAutoRestart(XRgb2gray_top *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_AP_CTRL, 0);
}

void XRgb2gray_top_Set_m_axi_in(XRgb2gray_top *InstancePtr, u64 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_IN_DATA, (u32)(Data));
    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_IN_DATA + 4, (u32)(Data >> 32));
}

u64 XRgb2gray_top_Get_m_axi_in(XRgb2gray_top *InstancePtr) {
    u64 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_IN_DATA);
    Data += (u64)XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_IN_DATA + 4) << 32;
    return Data;
}

void XRgb2gray_top_Set_m_axi_out(XRgb2gray_top *InstancePtr, u64 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_OUT_DATA, (u32)(Data));
    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_OUT_DATA + 4, (u32)(Data >> 32));
}

u64 XRgb2gray_top_Get_m_axi_out(XRgb2gray_top *InstancePtr) {
    u64 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_OUT_DATA);
    Data += (u64)XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_M_AXI_OUT_DATA + 4) << 32;
    return Data;
}

void XRgb2gray_top_Set_addr_in(XRgb2gray_top *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_ADDR_IN_DATA, Data);
}

u32 XRgb2gray_top_Get_addr_in(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_ADDR_IN_DATA);
    return Data;
}

void XRgb2gray_top_Set_addr_out(XRgb2gray_top *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_ADDR_OUT_DATA, Data);
}

u32 XRgb2gray_top_Get_addr_out(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_ADDR_OUT_DATA);
    return Data;
}

void XRgb2gray_top_Set_num_pixels(XRgb2gray_top *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_NUM_PIXELS_DATA, Data);
}

u32 XRgb2gray_top_Get_num_pixels(XRgb2gray_top *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_NUM_PIXELS_DATA);
    return Data;
}

void XRgb2gray_top_InterruptGlobalEnable(XRgb2gray_top *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_GIE, 1);
}

void XRgb2gray_top_InterruptGlobalDisable(XRgb2gray_top *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_GIE, 0);
}

void XRgb2gray_top_InterruptEnable(XRgb2gray_top *InstancePtr, u32 Mask) {
    u32 Register;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Register =  XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_IER);
    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_IER, Register | Mask);
}

void XRgb2gray_top_InterruptDisable(XRgb2gray_top *InstancePtr, u32 Mask) {
    u32 Register;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Register =  XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_IER);
    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_IER, Register & (~Mask));
}

void XRgb2gray_top_InterruptClear(XRgb2gray_top *InstancePtr, u32 Mask) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XRgb2gray_top_WriteReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_ISR, Mask);
}

u32 XRgb2gray_top_InterruptGetEnabled(XRgb2gray_top *InstancePtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    return XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_IER);
}

u32 XRgb2gray_top_InterruptGetStatus(XRgb2gray_top *InstancePtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    return XRgb2gray_top_ReadReg(InstancePtr->Control_BaseAddress, XRGB2GRAY_TOP_CONTROL_ADDR_ISR);
}

