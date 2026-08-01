# ============================================================================
# Makefile -- RAM con esclavo AXI4 Full (rol E, Tarea 4 EC4)
#
# Detalles que NO son gratuitos (todos verificados en esta maquina):
#   * MEM_WORDS: cada etapa lleva su tamano natural en su propio .v. Se puede
#     forzar con `make stageN MEM_WORDS=...`, que pasa -P a Icarus; funciona
#     porque el parametro esta declarado en el TOP del testbench (`tb`) y se
#     propaga al DUT. Sobre una instancia hija, `iverilog -P` se acepta pero
#     NO aplica (comprobado).
#   * Cada corrida va envuelta en `timeout`: un binario de Verilator que no
#     llega a $finish no termina nunca.
#   * `-Wall` de Verilator convierte los warnings en ERROR. El nucleo no declara
#     las senales que el contrato manda ignorar (awprot/awcache/awlock/awqos:
#     las recibe la interfaz y el wrapper no las conecta), asi que lint-final
#     pasa limpio SIN ningun lint_off. `lint` a secas si silencia UNUSEDSIGNAL/
#     UNUSEDPARAM: es el permisivo, para mientras se escribe codigo nuevo.
#   * Verilator no genera VCD sin --trace, y no avisa.
# ============================================================================

RTL        := axi4_ram_slave.v
FULL_WORDS := 8388608          # 64 MB: el tamano de entrega
# Interfaz AXI4 real del rol B (por defecto). Si no existe, cae al stub.
AXI4_IF_REAL := ../../tb/interfaces/axi4_if.sv
AXI4_IF_STUB := $(TBDIR)/stub/axi4_if_stub.sv
AXI4_IF ?= $(if $(wildcard $(AXI4_IF_REAL)),$(AXI4_IF_REAL),$(AXI4_IF_STUB))
TBDIR      := tb
SIMDIR     := sim
DOCDIR     := doc
BRIDGE_DIR := ../bridge_dpi

IVERILOG   := iverilog
IVFLAGS    := -g2012 -Wall -I$(TBDIR) -s tb
VVP        := vvp
VERILATOR  := verilator
TIMEOUT    := timeout 120

MEM_WORDS  ?=
IVPARAM    := $(if $(MEM_WORDS),-Ptb.MEM_WORDS=$(MEM_WORDS))

# Etapas de Icarus y etapas de Verilator. Anadir una etapa nueva es tocar
# SOLO una de estas dos listas.
IV_STAGES  := 0 1 2 3 4 5 6 7 8 10 11
VL_STAGES  := 9
STAGES     := $(IV_STAGES) $(VL_STAGES)

.PHONY: lint lint-final regress clean doc help hang full check-single-writer

help:
	@echo "make lint            - lint permisivo (desarrollo)"
	@echo "make lint-final      - lint estricto -Wall (el que usa regress)"
	@echo "make cosim-lint      - lint del top real de co-simulacion DPI/SystemC"
	@echo "make cosim-vl        - cosim completa en Verilator (wrapper + DPI C++)"
	@echo "make cosim-vl-metric - igual que cosim-vl pero con tiempo y RSS"
	@echo "                        (C++ DPI en $(BRIDGE_DIR)/dpi/)"
	@echo "make dpi-gate        - puerta minima DPI SV<->C++ con consumo de ciclos"
	@echo "make stage0..stage11 - corre una etapa (MEM_WORDS=N para cambiar tamano)"
	@echo "make stage9          - etapa 9: wrapper sobre la axi4_if (Verilator)"
	@echo "                       por defecto usa $(AXI4_IF_REAL); override: AXI4_IF=/ruta/axi4_if.sv"
	@echo "make regress         - todas las etapas en secuencia"
	@echo "make wave-N          - abre la onda de la etapa N (N != 9: esa no genera VCD)"
	@echo "make wave-hang       - la onda del cuelgue deliberado"
	@echo "make clean           - borra sim/ y los objetos de Verilator"
	@echo "make hang            - ejercicio de la etapa 0: cuelgue deliberado"
	@echo "make full            - corrida a 64 MB en Icarus y Verilator (tiempo y RSS)"
	@echo "make doc             - regenera los .png/.svg desde los .dot"

# ---------------------------------------------------------------------------
# Lint
# ---------------------------------------------------------------------------
# `lint` es el permisivo (util mientras se escribe codigo nuevo). El que corre
# la regresion es `lint-final`, con -Wall estricto y sin excepciones globales.
lint:
	$(VERILATOR) --lint-only -Wall -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM --top-module axi4_ram_slave $(RTL)
	@$(MAKE) --no-print-directory check-single-writer
	@echo "lint OK"

lint-final:
	$(VERILATOR) --lint-only -Wall --top-module axi4_ram_slave $(RTL)
	@$(MAKE) --no-print-directory check-single-writer
	@echo "lint-final OK"

cosim-lint:
	$(VERILATOR) --lint-only --sv --timing -Wno-DECLFILENAME -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	    -Itb --top-module tb \
	    $(RTL) axi4_ram_slave_axi4if.sv $(AXI4_IF) \
	    tb/systemc_dpi_pkg.sv tb/tb_systemc_dpi_top.sv
	@echo "cosim-lint OK"

cosim-vl: $(SIMDIR)
	@echo "=== cosim Verilator: top DPI + wrapper + DUT ==="
	rm -rf $(SIMDIR)/obj_cosim_vl
	$(VERILATOR) --binary --timing --sv -Wno-DECLFILENAME -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	    --top-module tb -I$(TBDIR) -Mdir $(SIMDIR)/obj_cosim_vl \
	    $(RTL) axi4_ram_slave_axi4if.sv $(AXI4_IF) \
	    $(TBDIR)/systemc_dpi_pkg.sv $(TBDIR)/tb_systemc_dpi_top.sv \
	    $(abspath $(BRIDGE_DIR)/dpi/systemc_dpi_vl_stub.cpp) > /dev/null
	$(TIMEOUT) $(SIMDIR)/obj_cosim_vl/Vtb

cosim-vl-metric: $(SIMDIR)
	@echo "=== cosim Verilator (metricas) ==="
	rm -rf $(SIMDIR)/obj_cosim_vl
	$(VERILATOR) --binary --timing --sv -Wno-DECLFILENAME -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	    --top-module tb -I$(TBDIR) -Mdir $(SIMDIR)/obj_cosim_vl \
	    $(RTL) axi4_ram_slave_axi4if.sv $(AXI4_IF) \
	    $(TBDIR)/systemc_dpi_pkg.sv $(TBDIR)/tb_systemc_dpi_top.sv \
	    $(abspath $(BRIDGE_DIR)/dpi/systemc_dpi_vl_stub.cpp) > /dev/null
	-/usr/bin/time -f "cosim-vl: %e s, RSS %M KB" $(TIMEOUT) $(SIMDIR)/obj_cosim_vl/Vtb

# Verilator NO detecta dos always escribiendo la misma memoria (comprobado).
# Este chequeo manual sustituye a la red de seguridad que no existe.
check-single-writer:
	@n=$$(grep -c 'mem\[.*<=' $(RTL) || true); \
	if [ "$$n" -gt 1 ]; then \
	  echo "ERROR: $$n lineas asignan mem[] en $(RTL). Solo un always puede escribir la memoria (regla R4); si la segunda esta en el MISMO always, ajusta este chequeo."; \
	  grep -n 'mem\[.*<=' $(RTL); exit 1; \
	fi

# ---------------------------------------------------------------------------
# Etapas 0..8 (Icarus)
# ---------------------------------------------------------------------------
define STAGE_rule
stage$(1): $(SIMDIR)
	@echo "=== etapa $(1) ==="
	$$(IVERILOG) $$(IVFLAGS) $$(IVPARAM) \
	    -DVCD_FILE=\"$$(SIMDIR)/stage$(1).vcd\" \
	    -o $$(SIMDIR)/stage$(1).vvp $$(RTL) $$(wildcard $$(TBDIR)/tb_stage$(1)_*.v)
	$$(TIMEOUT) $$(VVP) $$(SIMDIR)/stage$(1).vvp

wave-$(1):
	env -i HOME=$$$$HOME DISPLAY=$$$$DISPLAY XAUTHORITY=$$$$XAUTHORITY \
	    gtkwave $$(SIMDIR)/stage$(1).vcd $$(wildcard $$(SIMDIR)/stage$(1).gtkw) &
endef
$(foreach s,$(IV_STAGES),$(eval $(call STAGE_rule,$(s))))

# Etapa 9: el wrapper usa un puerto de interfaz, que Icarus 12 NO soporta.
# Esta etapa corre bajo VERILATOR.
stage9: $(SIMDIR)
	@echo "=== etapa 9: wrapper sobre axi4_if (Verilator) ==="
	$(VERILATOR) --binary --timing -Wno-DECLFILENAME -Wno-WIDTHEXPAND \
	    --top-module tb -Mdir $(SIMDIR)/obj_s9 \
	    $(RTL) axi4_ram_slave_axi4if.sv \
	    $(AXI4_IF) $(TBDIR)/tb_stage9_wrapper.sv > /dev/null
	$(TIMEOUT) $(SIMDIR)/obj_s9/Vtb

# ---------------------------------------------------------------------------
# Puerta de integracion DPI (rol D): ida y vuelta SV <-> C++ consumiendo
# tiempo de simulacion real mediante callback entre SV y C++.
# ---------------------------------------------------------------------------
dpi-gate: $(SIMDIR)
	@echo "=== puerta DPI: SV <-> C++ con avance de tiempo ==="
	rm -rf $(SIMDIR)/obj_dpi_gate
	$(VERILATOR) --binary --timing --sv -Wno-DECLFILENAME -Wno-WIDTHEXPAND \
	    --top-module tb -I$(TBDIR) -Mdir $(SIMDIR)/obj_dpi_gate \
	    $(RTL) $(TBDIR)/tb_stage12_dpi_gate.sv $(abspath $(BRIDGE_DIR)/dpi/dpi_gate.cpp) > /dev/null
	$(TIMEOUT) $(SIMDIR)/obj_dpi_gate/Vtb

# ---------------------------------------------------------------------------
# Ejercicio de la etapa 0: cuelgue deliberado, para aprender a leer una onda
# ---------------------------------------------------------------------------
hang: $(SIMDIR)
	$(IVERILOG) $(IVFLAGS) -DHANG_DEMO -DWATCHDOG_NS=5000 \
	    -DVCD_FILE=\"$(SIMDIR)/hang.vcd\" \
	    -o $(SIMDIR)/hang.vvp $(RTL) $(TBDIR)/tb_stage0_smoke.v
	-$(TIMEOUT) $(VVP) $(SIMDIR)/hang.vvp
	@echo ""
	@echo "Ahora: make wave-hang   y busca el ciclo donde todo se detiene."

wave-hang:
	env -i HOME=$$HOME DISPLAY=$$DISPLAY XAUTHORITY=$$XAUTHORITY \
	    gtkwave $(SIMDIR)/hang.vcd &

# ---------------------------------------------------------------------------
# Regresion
# ---------------------------------------------------------------------------
regress: lint-final
	@fail=0; n=0; \
	for s in $(STAGES); do \
	  n=$$((n+1)); \
	  $(MAKE) --no-print-directory stage$$s || fail=$$((fail+1)); \
	done; \
	echo ""; \
	if [ $$fail -eq 0 ]; then \
	  echo "=== TODOS LOS TESTS PASARON (N=$$n) ==="; \
	else \
	  echo "=== $$fail ETAPA(S) FALLARON de $$n ==="; exit 1; \
	fi

# ---------------------------------------------------------------------------
# Corrida a escala real: 64 MB. Se reportan los DOS numeros porque el que le
# sirve al rol D es el de 4 estados (Icarus/XSim), no el de Verilator.
# ---------------------------------------------------------------------------
full: $(SIMDIR)
	@echo "--- Icarus, 4 estados (este es el numero que necesita D) ---"
	$(IVERILOG) $(IVFLAGS) -Ptb.MEM_WORDS=$(FULL_WORDS) -DNO_VCD \
	    -o $(SIMDIR)/full.vvp $(RTL) $(TBDIR)/tb_stage7_b2b.v
	-/usr/bin/time -f "icarus: %e s, RSS %M KB" $(TIMEOUT) $(VVP) $(SIMDIR)/full.vvp
	@echo "--- Verilator, 2 estados (subestima la memoria a la mitad) ---"
	$(VERILATOR) --binary --timing -GMEM_WORDS=$(FULL_WORDS) --top-module tb -DNO_VCD \
	    -Wno-DECLFILENAME -Wno-WIDTHEXPAND -Wno-INITIALDLY -Wno-WIDTHTRUNC \
	    -I$(TBDIR) -Mdir $(SIMDIR)/obj_full $(RTL) $(TBDIR)/tb_stage7_b2b.v >/dev/null
	-/usr/bin/time -f "verilator: %e s, RSS %M KB" $(TIMEOUT) $(SIMDIR)/obj_full/Vtb

# ---------------------------------------------------------------------------
# Diagramas
# ---------------------------------------------------------------------------
DOTS := $(wildcard $(DOCDIR)/*.dot)
doc: $(DOTS:.dot=.png) $(DOTS:.dot=.svg)

$(DOCDIR)/%.png: $(DOCDIR)/%.dot
	dot -Tpng $< -o $@

$(DOCDIR)/%.svg: $(DOCDIR)/%.dot
	dot -Tsvg $< -o $@

# ---------------------------------------------------------------------------
$(SIMDIR):
	@mkdir -p $(SIMDIR)

clean:
	rm -rf $(SIMDIR) obj_dir
