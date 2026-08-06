CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
COMPAT_DIR := ../Golden/compat
BUILD_DIR := build

.PHONY: all test conventional multiplier-forward multiplier-inverse clean

all: test

test: conventional multiplier-forward multiplier-inverse

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

conventional: $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I$(COMPAT_DIR) -I. fwht_baseline.cpp fwht_baseline_tb.cpp -o $(BUILD_DIR)/fwht_baseline_tb
	$(BUILD_DIR)/fwht_baseline_tb

multiplier-forward: $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I$(COMPAT_DIR) -I. wht_multiplier_baseline.cpp wht_multiplier_baseline_tb.cpp -o $(BUILD_DIR)/wht_multiplier_forward_tb
	$(BUILD_DIR)/wht_multiplier_forward_tb

multiplier-inverse: $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I$(COMPAT_DIR) -I. wht_multiplier_baseline.cpp wht_multiplier_inverse_tb.cpp -o $(BUILD_DIR)/wht_multiplier_inverse_tb
	$(BUILD_DIR)/wht_multiplier_inverse_tb

clean:
	rm -rf $(BUILD_DIR)
