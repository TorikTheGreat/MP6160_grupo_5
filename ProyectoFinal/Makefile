CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
BUILD_DIR := build
COMPAT_DIR := Golden/compat

.PHONY: test verify isolated baseline hls-all clean

test: verify isolated baseline

verify:
	$(MAKE) -C Golden verify

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

isolated: $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I$(COMPAT_DIR) -ISource Source/wht_core_isolated.cpp TB/wht_core_isolated_forward_tb.cpp -o $(BUILD_DIR)/isolated_forward_tb
	$(BUILD_DIR)/isolated_forward_tb
	$(CXX) $(CXXFLAGS) -I$(COMPAT_DIR) -ISource Source/wht_core_isolated.cpp TB/wht_core_isolated_inverse_tb.cpp -o $(BUILD_DIR)/isolated_inverse_tb
	$(BUILD_DIR)/isolated_inverse_tb

baseline:
	$(MAKE) -C Baseline test

hls-all:
	cd HLS && ./run_all_variants.sh

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C Golden clean
	$(MAKE) -C Baseline clean
	rm -rf HLS/work/main_forward HLS/work/main_inverse
	rm -rf HLS/work/isolated_forward HLS/work/isolated_inverse
	rm -rf HLS/work/baseline_forward HLS/work/baseline_inverse
	@echo "Generated HLS/Vivado work directories removed. Versioned reports were preserved."
