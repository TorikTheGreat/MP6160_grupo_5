.PHONY: clean

clean:
	@echo "Limpiando archivos generados por HLS, Vivado y tests C++..."
	rm -rf HLS/wht_hls_work HLS/wht_hls_forward HLS/wht_hls_inverse
	rm -rf HLS/vivado_work HLS/vivado_forward HLS/vivado_inverse
	rm -f HLS/metrics_prelim*.md HLS/metrics_impl*.md
	rm -f HLS/vivado*.log HLS/vivado*.jou HLS/vitis_hls.log
	rm -f test_inverso
	$(MAKE) -C Golden clean
	@echo "¡Limpieza completada exitosamente!"
