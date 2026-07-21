// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.1 (64-bit)
// Tool Version Limit: 2024.05
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef XRGB2GRAY_TOP_H
#define XRGB2GRAY_TOP_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files *********************************/
#ifndef __linux__
#include "xil_types.h"
#include "xil_assert.h"
#include "xstatus.h"
#include "xil_io.h"
#else
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stddef.h>
#endif
#include "xrgb2gray_top_hw.h"

/**************************** Type Definitions ******************************/
#ifdef __linux__
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
#else
typedef struct {
#ifdef SDT
    char *Name;
#else
    u16 DeviceId;
#endif
    u64 Control_BaseAddress;
} XRgb2gray_top_Config;
#endif

typedef struct {
    u64 Control_BaseAddress;
    u32 IsReady;
} XRgb2gray_top;

typedef u32 word_type;

/***************** Macros (Inline Functions) Definitions *********************/
#ifndef __linux__
#define XRgb2gray_top_WriteReg(BaseAddress, RegOffset, Data) \
    Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))
#define XRgb2gray_top_ReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))
#else
#define XRgb2gray_top_WriteReg(BaseAddress, RegOffset, Data) \
    *(volatile u32*)((BaseAddress) + (RegOffset)) = (u32)(Data)
#define XRgb2gray_top_ReadReg(BaseAddress, RegOffset) \
    *(volatile u32*)((BaseAddress) + (RegOffset))

#define Xil_AssertVoid(expr)    assert(expr)
#define Xil_AssertNonvoid(expr) assert(expr)

#define XST_SUCCESS             0
#define XST_DEVICE_NOT_FOUND    2
#define XST_OPEN_DEVICE_FAILED  3
#define XIL_COMPONENT_IS_READY  1
#endif

/************************** Function Prototypes *****************************/
#ifndef __linux__
#ifdef SDT
int XRgb2gray_top_Initialize(XRgb2gray_top *InstancePtr, UINTPTR BaseAddress);
XRgb2gray_top_Config* XRgb2gray_top_LookupConfig(UINTPTR BaseAddress);
#else
int XRgb2gray_top_Initialize(XRgb2gray_top *InstancePtr, u16 DeviceId);
XRgb2gray_top_Config* XRgb2gray_top_LookupConfig(u16 DeviceId);
#endif
int XRgb2gray_top_CfgInitialize(XRgb2gray_top *InstancePtr, XRgb2gray_top_Config *ConfigPtr);
#else
int XRgb2gray_top_Initialize(XRgb2gray_top *InstancePtr, const char* InstanceName);
int XRgb2gray_top_Release(XRgb2gray_top *InstancePtr);
#endif

void XRgb2gray_top_Start(XRgb2gray_top *InstancePtr);
u32 XRgb2gray_top_IsDone(XRgb2gray_top *InstancePtr);
u32 XRgb2gray_top_IsIdle(XRgb2gray_top *InstancePtr);
u32 XRgb2gray_top_IsReady(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_Continue(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_EnableAutoRestart(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_DisableAutoRestart(XRgb2gray_top *InstancePtr);

void XRgb2gray_top_Set_m_axi_in(XRgb2gray_top *InstancePtr, u64 Data);
u64 XRgb2gray_top_Get_m_axi_in(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_Set_m_axi_out(XRgb2gray_top *InstancePtr, u64 Data);
u64 XRgb2gray_top_Get_m_axi_out(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_Set_addr_in(XRgb2gray_top *InstancePtr, u32 Data);
u32 XRgb2gray_top_Get_addr_in(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_Set_addr_out(XRgb2gray_top *InstancePtr, u32 Data);
u32 XRgb2gray_top_Get_addr_out(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_Set_num_pixels(XRgb2gray_top *InstancePtr, u32 Data);
u32 XRgb2gray_top_Get_num_pixels(XRgb2gray_top *InstancePtr);

void XRgb2gray_top_InterruptGlobalEnable(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_InterruptGlobalDisable(XRgb2gray_top *InstancePtr);
void XRgb2gray_top_InterruptEnable(XRgb2gray_top *InstancePtr, u32 Mask);
void XRgb2gray_top_InterruptDisable(XRgb2gray_top *InstancePtr, u32 Mask);
void XRgb2gray_top_InterruptClear(XRgb2gray_top *InstancePtr, u32 Mask);
u32 XRgb2gray_top_InterruptGetEnabled(XRgb2gray_top *InstancePtr);
u32 XRgb2gray_top_InterruptGetStatus(XRgb2gray_top *InstancePtr);

#ifdef __cplusplus
}
#endif

#endif
