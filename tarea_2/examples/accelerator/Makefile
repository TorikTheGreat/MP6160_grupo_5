# Testbench del acelerador. Usa SYSTEMC_HOME del entorno (source ../../activate.sh)
# o cae al tools/ local de la tarea. Incluye los headers de ../../include (ram, accelerator).
SYSTEMC_HOME ?= $(abspath ../../tools/systemc)
CXX      = g++
CXXFLAGS = -std=c++17 -I$(SYSTEMC_HOME)/include -I../../include
LDFLAGS  = -L$(SYSTEMC_HOME)/lib -Wl,-rpath,$(SYSTEMC_HOME)/lib
LDLIBS   = -lsystemc

tb_accelerator: tb_accelerator.cpp ../../include/accelerator.h ../../include/ram.h ../../include/rgb_to_gray.h
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

run: tb_accelerator
	./tb_accelerator

clean:
	rm -f tb_accelerator input.rgb input_img.rgb output.gray output_img.gray
	rm -f images/input.ppm images/output.pgm

.PHONY: run clean
