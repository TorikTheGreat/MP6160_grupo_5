# =====================================================================
#  Golden WHT: build, verificación y experimentos de entropía
#
#   make            -> compila todo lo que NO necesita SystemC
#   make verify     -> equivalencia vs núcleo HLS (fwd e inv) + round-trip del
#                      modelo y del hardware
#   make entropy    -> experimento de entropía con N=8 (el tamaño del hardware)
#   make sweep      -> barrido de bloque N = 8/16/32 + control de sesgo del estimador
#   make visual     -> figura original / coeficientes / reconstrucción / diferencia
#   make test       -> verify + entropy (toda la verificación reproducible)
#   make datasets   -> genera los PGM deterministas
#   make systemc    -> demo/testbench SystemC        [requiere libsystemc-dev]
#   make all-sc     -> todo, incluido SystemC
#   make clean
#
#  SystemC: los objetivos por defecto NO lo enlazan, para que `make` funcione en
#  una máquina sin libsystemc instalada. El envoltorio SystemC va aparte, en
#  `make systemc`.
#
#  ap_int: se usa el shim `compat/ap_int.h`, que replica la semántica de
#  ap_int<W> para las operaciones que usa el núcleo (+, -, >> y salida a
#  ostream). Con Vitis instalado, quitar "-Icompat" para el ap_int.h real.
#  Es una limitación conocida y declarada: la verificación es equivalencia a
#  nivel de fuente C++, no contra la RTL sintetizada.
# =====================================================================
CXX      ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wno-unknown-pragmas
CORE     := ../Source
INC      := -I$(CORE) -Icompat -Isrc -Isystemc
BUILD    := build
DATA     := data
PGM      := $(addprefix $(DATA)/,flat.pgm ramp.pgm edges.pgm natural.pgm noise.pgm)
VIS_SRC  ?= $(DATA)/natural.pgm
VIS_BASE := $(BUILD)/vis

.PHONY: all all-sc verify systemc datasets entropy sweep visual test clean

# Por defecto, todo menos SystemC (ver nota de la cabecera).
all: $(BUILD)/tb_equivalence $(BUILD)/tb_equivalence_inv $(BUILD)/tb_roundtrip \
     $(BUILD)/tb_roundtrip_hw $(BUILD)/entropy $(BUILD)/entropy_sweep $(BUILD)/make_visual

all-sc: all $(BUILD)/tb_sc

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/tb_equivalence: $(CORE)/wht_core.cpp src/wht_golden.cpp tb/tb_equivalence.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/tb_equivalence_inv: $(CORE)/wht_core.cpp src/wht_golden.cpp tb/tb_equivalence_inv.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/tb_roundtrip: src/wht_golden.cpp tb/tb_roundtrip.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/tb_roundtrip_hw: $(CORE)/wht_core.cpp src/wht_golden.cpp tb/tb_roundtrip_hw.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/tb_sc: $(CORE)/wht_core.cpp src/wht_golden.cpp systemc/tb_sc_main.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -lsystemc -o $@

$(BUILD)/entropy: src/wht_golden.cpp analysis/entropy_experiment.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/entropy_sweep: src/wht_golden.cpp analysis/entropy_sweep.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(BUILD)/make_visual: src/wht_golden.cpp analysis/make_visual.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INC) $^ -o $@

$(DATA)/.stamp: data/gen_datasets.py
	python3 data/gen_datasets.py && touch $(DATA)/.stamp
datasets: $(DATA)/.stamp

verify: $(BUILD)/tb_equivalence $(BUILD)/tb_equivalence_inv $(BUILD)/tb_roundtrip \
        $(BUILD)/tb_roundtrip_hw
	@echo "== E4: equivalencia golden vs nucleo HLS (forward) =="; ./$(BUILD)/tb_equivalence
	@echo "== E4b: equivalencia golden vs nucleo HLS (inverso) =="; ./$(BUILD)/tb_equivalence_inv
	@echo "== E5/E5b: round-trip lossless del MODELO + anti-overflow =="; ./$(BUILD)/tb_roundtrip
	@echo "== E6: round-trip del HARDWARE =="; ./$(BUILD)/tb_roundtrip_hw

systemc: $(BUILD)/tb_sc
	./$(BUILD)/tb_sc

entropy: $(BUILD)/entropy $(DATA)/.stamp
	./$(BUILD)/entropy $(PGM)

sweep: $(BUILD)/entropy_sweep $(DATA)/.stamp
	./$(BUILD)/entropy_sweep $(PGM)

# Figura de 4 paneles. Requiere python3 con Pillow y matplotlib.
# VIS_SRC elige la imagen (por defecto natural.pgm).
visual: $(BUILD)/make_visual $(DATA)/.stamp
	./$(BUILD)/make_visual $(VIS_SRC) $(VIS_BASE)
	python3 analysis/make_visual.py $(VIS_BASE)
	@echo "figura en $(VIS_BASE).png"

test: verify entropy

clean:
	rm -rf $(BUILD) $(DATA)/.stamp
