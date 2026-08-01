# Verificación del entorno SystemC + TLM 2.0.
# SYSTEMC_HOME se toma de activate.sh; si no, cae al tools/ local de la tarea.
SYSTEMC_HOME ?= $(abspath ../../tools/systemc)
CXX      = g++
CXXFLAGS = -std=c++17 -I$(SYSTEMC_HOME)/include
LDFLAGS  = -L$(SYSTEMC_HOME)/lib -Wl,-rpath,$(SYSTEMC_HOME)/lib
LDLIBS   = -lsystemc

hello_tlm: hello_tlm.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

run: hello_tlm
	./hello_tlm

clean:
	rm -f hello_tlm

.PHONY: run clean
