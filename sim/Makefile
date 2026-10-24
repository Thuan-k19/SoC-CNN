# ==============================================================================
# Makefile for MAC PE Simulation using Icarus Verilog and GTKWave
# ==============================================================================

# Tools
IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

# Flags (-g2012 enables SystemVerilog IEEE 1800-2012 support)
IVFLAGS  = -g2012 -Wall

# Paths
RTL_DIR  = ../rtl
TB_DIR   = ../tb

# Source files
SRCS     = $(RTL_DIR)/mac_pe.sv $(TB_DIR)/tb_mac_pe.sv
TOP_TB   = tb_mac_pe
OUT_VVP  = mac_pe_tb.vvp
VCD_FILE = mac_pe_tb.vcd

.PHONY: all compile sim wave clean help

all: compile sim

compile: $(SRCS)
	@echo "===> Compiling SystemVerilog sources with $(IVERILOG)..."
	$(IVERILOG) $(IVFLAGS) -s $(TOP_TB) -o $(OUT_VVP) $(SRCS)
	@echo "===> Compilation successful: $(OUT_VVP)"

sim: $(OUT_VVP)
	@echo "===> Running simulation with $(VVP)..."
	$(VVP) $(OUT_VVP)

wave: $(VCD_FILE)
	@echo "===> Opening waveform with $(GTKWAVE)..."
	$(GTKWAVE) $(VCD_FILE) &

clean:
	@echo "===> Cleaning simulation artifacts..."
	rm -f $(OUT_VVP) $(VCD_FILE) *.log

help:
	@echo "Available targets:"
	@echo "  make all     : Compile and run simulation (default)"
	@echo "  make compile : Compile RTL and Testbench using iverilog"
	@echo "  make sim     : Run simulation binary with vvp"
	@echo "  make wave    : Open waveform with gtkwave"
	@echo "  make clean   : Remove generated files (.vvp, .vcd, .log)"
