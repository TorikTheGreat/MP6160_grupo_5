# Build del testbench de sistema (CPU + RAM + Acelerador via TLM).
# Usa SYSTEMC_HOME del entorno (source ../activate.sh) o el tools/ local.
SYSTEMC_HOME ?= $(abspath ../tools/systemc)
CXX      = g++
CXXFLAGS = -std=c++17 -I$(SYSTEMC_HOME)/include -I../include
LDFLAGS  = -L$(SYSTEMC_HOME)/lib -Wl,-rpath,$(SYSTEMC_HOME)/lib
LDLIBS   = -lsystemc

HEADERS = ../include/cpu.h ../include/ram.h ../include/accelerator.h ../include/rgb_to_gray.h

tb_cpu_ram_accel: tb_cpu_ram_accel.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

run: tb_cpu_ram_accel
	./tb_cpu_ram_accel

clean:
	rm -f tb_cpu_ram_accel input.rgb output.gray images/output.gray images/output.png

.PHONY: run clean
