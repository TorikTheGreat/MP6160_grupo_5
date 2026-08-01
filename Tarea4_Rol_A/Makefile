.RECIPEPREFIX := >

SYSTEMC_HOME ?= $(CURDIR)/tools/systemc

CXX      ?= g++
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra \
            -Iinclude \
            -I$(SYSTEMC_HOME)/include

LDFLAGS  := -L$(SYSTEMC_HOME)/lib \
            -Wl,-rpath,$(SYSTEMC_HOME)/lib

LDLIBS   := -lsystemc -pthread

BUILD_DIR := build

# Baseline del sistema original con RAM SystemC
TARGET  := $(BUILD_DIR)/tb_cpu_ram_accel
SOURCE  := tests/tb_cpu_ram_accel.cpp
HEADERS := $(wildcard include/*.h)

# Prueba local del proxy
PROXY_TEST_TARGET  := $(BUILD_DIR)/tb_ram_rtl_proxy_mock
PROXY_TEST_SOURCES := tests/tb_ram_rtl_proxy_mock.cpp src/ram_rtl_proxy.cpp

# Flujo completo usando el proxy y una memoria simulada
PROXY_E2E_TARGET  := $(BUILD_DIR)/tb_cpu_ram_accel_proxy_mock
PROXY_E2E_SOURCES := tests/tb_cpu_ram_accel_proxy_mock.cpp \
                     src/ram_rtl_proxy.cpp

# Prueba portable de las cuatro funciones DPI
DPI_TEST_TARGET := $(BUILD_DIR)/tb_systemc_dpi_bridge
DPI_TEST_SOURCES := tests/tb_systemc_dpi_bridge.cpp \
                    src/ram_rtl_proxy.cpp \
                    src/systemc_dpi_bridge.cpp

# Comprobación de compilación del wrapper
WRAPPER_OBJECT := $(BUILD_DIR)/systemc_dpi_wrapper.o
WRAPPER_SOURCE := src/systemc_dpi_wrapper.cpp

# Prueba end-to-end portable del wrapper
WRAPPER_TEST_TARGET := $(BUILD_DIR)/tb_systemc_dpi_wrapper_portable
WRAPPER_TEST_SOURCES := tests/tb_systemc_dpi_wrapper_portable.cpp \
                        src/systemc_dpi_wrapper.cpp \
                        src/systemc_dpi_bridge.cpp \
                        src/ram_rtl_proxy.cpp

all: $(TARGET)

$(TARGET): $(SOURCE) $(HEADERS)
>mkdir -p $(BUILD_DIR)
>$(CXX) $(CXXFLAGS) $(SOURCE) -o $(TARGET) $(LDFLAGS) $(LDLIBS)

baseline: $(TARGET)
>mkdir -p logs
>./$(TARGET) 2>&1 | tee logs/baseline_systemc.log

$(PROXY_TEST_TARGET): $(PROXY_TEST_SOURCES) include/ram_rtl_proxy.h
>mkdir -p $(BUILD_DIR)
>$(CXX) $(CXXFLAGS) $(PROXY_TEST_SOURCES) -o $(PROXY_TEST_TARGET) $(LDFLAGS) $(LDLIBS)

proxy-test: $(PROXY_TEST_TARGET)
>mkdir -p logs
>./$(PROXY_TEST_TARGET) 2>&1 | tee logs/proxy_mock.log

$(PROXY_E2E_TARGET): $(PROXY_E2E_SOURCES) \
                     include/ram_rtl_proxy.h \
                     include/mock_axi_memory.h
>mkdir -p $(BUILD_DIR)
>$(CXX) $(CXXFLAGS) $(PROXY_E2E_SOURCES) -o $(PROXY_E2E_TARGET) $(LDFLAGS) $(LDLIBS)

proxy-e2e: $(PROXY_E2E_TARGET)
>mkdir -p logs
>./$(PROXY_E2E_TARGET) 2>&1 | tee logs/proxy_end_to_end.log

$(DPI_TEST_TARGET): $(DPI_TEST_SOURCES) \
                    include/ram_rtl_proxy.h \
                    include/systemc_dpi_bridge.h
>mkdir -p $(BUILD_DIR)
>$(CXX) $(CXXFLAGS) $(DPI_TEST_SOURCES) -o $(DPI_TEST_TARGET) $(LDFLAGS) $(LDLIBS)

dpi-test: $(DPI_TEST_TARGET)
>mkdir -p logs
>./$(DPI_TEST_TARGET) 2>&1 | tee logs/dpi_bridge_portable.log

$(WRAPPER_OBJECT): $(WRAPPER_SOURCE) \
                   include/systemc_dpi_bridge.h \
                   include/ram_rtl_proxy.h
>mkdir -p $(BUILD_DIR)
>$(CXX) $(CXXFLAGS) -c $(WRAPPER_SOURCE) -o $(WRAPPER_OBJECT)

wrapper-check: $(WRAPPER_OBJECT)
>@echo "SYSTEMC DPI WRAPPER: COMPILACIÓN PASS"

$(WRAPPER_TEST_TARGET): $(WRAPPER_TEST_SOURCES) \
                        include/systemc_dpi_bridge.h \
                        include/ram_rtl_proxy.h
>mkdir -p $(BUILD_DIR)
>$(CXX) $(CXXFLAGS) $(WRAPPER_TEST_SOURCES) -o $(WRAPPER_TEST_TARGET) $(LDFLAGS) $(LDLIBS)

wrapper-test: $(WRAPPER_TEST_TARGET)
>mkdir -p logs
>./$(WRAPPER_TEST_TARGET) 2>&1 | tee logs/wrapper_portable.log

test-all: baseline proxy-test proxy-e2e dpi-test wrapper-check wrapper-test
>@echo "TODAS LAS PRUEBAS PORTABLES DEL ROL A FINALIZARON"

clean:
>rm -rf $(BUILD_DIR)
>rm -f input.rgb output.gray

.PHONY: all baseline proxy-test proxy-e2e dpi-test wrapper-check wrapper-test test-all clean
