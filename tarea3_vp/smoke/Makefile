# Smoke test standalone (SystemC de la Tarea 2, sin gem5). Verifica el núcleo bit-exact.
SYSTEMC_HOME ?= $(abspath ../../tarea_2/tools/systemc)
CXX      = g++
CXXFLAGS = -std=c++17 -I$(SYSTEMC_HOME)/include -I../vp_accel
LDFLAGS  = -L$(SYSTEMC_HOME)/lib -Wl,-rpath,$(SYSTEMC_HOME)/lib
LDLIBS   = -lsystemc

smoke_test: smoke_test.cpp ../vp_accel/accelerator.h ../vp_accel/ram.h ../vp_accel/rgb_to_gray.h
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

run: smoke_test
	./smoke_test

clean:
	rm -f smoke_test in.rgb out.gray

.PHONY: run clean
