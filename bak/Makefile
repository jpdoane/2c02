HDLEXT=sv
SIMEXT=vvp
WAVEEXT=vcd

HDLDIR=hdl
HDMIDIR=hdmi
CLKDIR=clocking
SIMDIR=sim
TBDIR=test

CLKSOURCE = $(wildcard $(CLKDIR)/*.$(HDLEXT))
PPUSOURCE = $(wildcard $(HDLDIR)/*.$(HDLEXT))
HDMISOURCE = $(wildcard $(HDMIDIR)/*.$(HDLEXT))

# sim testbenches
PPUTB=ppu_tb
HDMITB=hdmi_tb

# synth tops
TOP_DIR=top/artyz7
HDMI_TOP=test_hdmi_upscale_top


WAVESAVEFILE=$(SIMDIR)/ppu.sav
WAVEOBJ=sim/ppu.vcd

VIEWTARGET = sim/ppu.vcd

## Vivado
VIVPROJDIR = ppu_artyz7
VIVADO = /opt/Xilinx/Vivado/2018.2/bin/vivado
VIVFLAGS = -mode batch #-nojournal -nolog -notrace
SYNTH_DIR = $(VIVPROJDIR)/ppu_artyz7.runssynth_1
IMPL_DIR = $(VIVPROJDIR)/ppu_artyz7.runs/impl_1
# LOADEDBITFILE = jpu_load.bit
# UPDATEMEMFLAGS = "-force"

DESIGN = test
DEVICE = xc7z010clg400-1
XDC_FILE = $(TOP_DIR)/artyz7.xdc


.PHONY: bitfile
bitfile: $(IMPL_DIR)/$(HDMI_TOP).bit

$(SYNTH_DIR)/%.dcp: $(SYNTH_DIR)/%.tcl $(XDC_FILE) $(CLKSOURCE) $(PPUSOURCE) $(HDMISOURCE) $(TOP_DIR)/%.sv 
	$(VIVADO) $(VIVFLAGS) -source $<

$(IMPL_DIR)/%.bit: $(IMPL_DIR)/%.tcl $(SYNTH_DIR)/%.dcp
	$(VIVADO) $(VIVFLAGS) -source $<

temp:
	iverilog -g2012 -o $@ \
					-s ppu_tb \
					-D'DUMP_WAVE_FILE="path"' \
					-I $(HDLDIR) $(PPUSOURCE) $(HDMISOURCE) $< \
					-Wall -Wno-timescale


.PHONY: all
all: $(WAVEOBJ)

.PHONY: view
view: $(VIEWTARGET)
	gtkwave $^ -a $(WAVESAVEFILE) &

# compute verilog sim
sim/%.$(SIMEXT): test/%.$(HDLEXT) $(PPUSOURCE) $(HDMISOURCE)
	iverilog -g2012 -o $@ \
					-s ppu_tb \
					-D'DUMP_WAVE_FILE="$(patsubst %.vvp,%.vcd,$@)"' \
					-I $(HDLDIR) $(PPUSOURCE) $(HDMISOURCE) $< \
					-Wall -Wno-timescale

%.$(WAVEEXT): %.$(SIMEXT)
	vvp $<
					
.PHONY: clean
clean:
	rm -rf sim/*.$(SIMEXT)
	rm -rf sim/*.$(WAVEEXT)
	rm -rf frames/*
	rm $(IMPL_DIR)/$(HDMI_TOP).bit

# keep intermediate files
.SECONDARY: