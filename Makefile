HDLDIR=hdl
SIMDIR=sim
TBDIR=test

HDLEXT=sv
SIMEXT=vvp
WAVEEXT=vcd

HDLSOURCES = $(wildcard $(HDLDIR)/*.$(HDLEXT))
PPUTESTBENCH=$(TBDIR)/ppu_tb.sv

WAVESAVEFILE=$(SIMDIR)/ppu.sav
WAVEOBJ=sim/ppu.vcd

VIEWTARGET = sim/ppu.vcd

.PHONY: all
all: $(WAVEOBJ)

.PHONY: view
view: $(VIEWTARGET)
	gtkwave $^ -a $(WAVESAVEFILE) &

# compute verilog sim
sim/ppu.$(SIMEXT): $(PPUTESTBENCH) $(HDLSOURCES)
	iverilog -g2012 -o $@ \
					-s ppu_tb \
					-D'DUMP_WAVE_FILE="$(patsubst %.vvp,%.vcd,$@)"' \
					-I $(HDLDIR) $(HDLSOURCES) $(PPUTESTBENCH)

# run verilog sim
sim/%.$(WAVEEXT): sim/%.$(SIMEXT)
	vvp $^

.PHONY: clean
clean:
	rm -rf sim/*.$(SIMEXT)
	rm -rf sim/*.$(WAVEEXT)
	rm -rf frames/*

# keep intermediate files
.SECONDARY: