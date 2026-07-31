# =====================================================================
#  Golden WHT. build, verificación y experimentos de entropía
# 
#   make            -> compila todo
#   make verify     -> equivalencia vs núcleo W1 + round-trip
#   make systemc    -> demo/testbench SystemC 
#   make datasets   -> genera los PGM deterministas 
#   make entropy    -> experimento de reducción de entropía
#   make test       -> verify + entropy (toda la verificación reproducible)
#   make clean
#
#  Nota: usa el shim compat/ap_int.h porque la máquina que usé no tiene Vitis
#  todavía (finalmente me contestaron, pronto lo instalo).
#  Con Vitis instalado, quitar "-Icompat" para usar el ap_int.h real.
#  SystemC: usa la libsystemc del sistema (-lsystemc, sin variables extra).
# =====================================================================
CXX      ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wno-unknown-pragmas
CORE     := ../Source
INC      := -I$(CORE) -Icompat -Isrc -Isystemc
BUILD    := build
DATA     := data
PGM      := $(addprefix $(DATA)/,flat.pgm ramp.pgm edges.pgm natural.pgm noise.pgm)

.PHONY: all verify systemc datasets entropy test clean

all: $(BUILD)/tb_equivalence $(BUILD)/tb_roundtrip $(BUILD)/tb_sc $(BUILD)/entropy

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/tb_equivalence: $(CORE)/wht_core.cpp src/wht_golden.cpp tb/tb_equivalence.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/tb_roundtrip: src/wht_golden.cpp tb/tb_roundtrip.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/tb_sc: $(CORE)/wht_core.cpp src/wht_golden.cpp systemc/tb_sc_main.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -lsystemc -o $@

$(BUILD)/entropy: src/wht_golden.cpp analysis/entropy_experiment.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(DATA)/.stamp: data/gen_datasets.py
	python3 data/gen_datasets.py && touch $(DATA)/.stamp
datasets: $(DATA)/.stamp

verify: $(BUILD)/tb_equivalence $(BUILD)/tb_roundtrip
	@echo "== E4: equivalencia golden vs nucleo W1 =="; ./$(BUILD)/tb_equivalence
	@echo "== E5/E5b: round-trip lossless + anti-overflow =="; ./$(BUILD)/tb_roundtrip

systemc: $(BUILD)/tb_sc
	./$(BUILD)/tb_sc

entropy: $(BUILD)/entropy $(DATA)/.stamp
	./$(BUILD)/entropy $(PGM)

test: verify entropy

clean:
	rm -rf $(BUILD) $(DATA)/.stamp
