PROJ_ROOT = $(abspath ../../..)
DEVICE_ROOT = $(abspath ..)

MODULES = $(PROJ_ROOT)/modules
CLK_SOURCE = $(wildcard $(MODULES)/clocks/*.sv)
HDMI_SOURCE = $(wildcard $(MODULES)/hdmi/*.sv)
PPU_SOURCE = $(wildcard $(MODULES)/ppu/*.sv)

CONSTRIANTS = $(wildcard $(MODULES)/clocks/*.xdc) $(wildcard $(DEVICE_ROOT)/*.xdc)

TOP=ppu_hdmi_top

TOP_SOURCE = $(abspath $(wildcard ./*.sv))
HDL_SOURCE = $(CLK_SOURCE) $(HDMI_SOURCE) $(PPU_SOURCE) $(TOP_SOURCE)

all: bitfile

## synth

SYNTH_PATH=$(TOP)_synth
SYNTH_TCL=$(TOP)_synth.tcl
SYNTH_DCP=$(SYNTH_PATH)/$(TOP).dcp

SRC_FILE=$(SYNTH_PATH)/sources.tcl

$(SRC_FILE): $(SYNTH_PATH) $(HDL_SOURCE)
	@rm -f $@; \
	for s in $(HDL_SOURCE) ; do \
		echo "$$s" >> $@; \
	done

XDC_FILE=$(SYNTH_PATH)/constraints.tcl

$(XDC_FILE): $(SYNTH_PATH) $(CONSTRIANTS)
	@rm -f $@; \
	for s in $(CONSTRIANTS) ; do \
		echo "$$s" >> $@; \
	done


show:
	@echo $(CONSTRIANTS)

.PHONY: synth
synth: $(SYNTH_DCP)

$(SYNTH_PATH):
	mkdir -p $(SYNTH_PATH)

$(SYNTH_DCP): $(SYNTH_TCL) $(XDC_FILE) $(SRC_FILE)
	cp $(SYNTH_TCL) $(SYNTH_PATH) && \
	cd $(SYNTH_PATH) && \
	vivado -m64 -mode batch -notrace -source $(SYNTH_TCL)

## impl

IMPL_PATH=$(TOP)_impl
IMPL_TCL=$(TOP)_impl.tcl
ROUTE_DCP=$(SYNTH_PATH)/$(TOP)_routed.dcp

.PHONY: impl
impl: $(ROUTE_DCP)

$(IMPL_PATH):
	mkdir -p $(IMPL_PATH)

$(ROUTE_DCP): $(IMPL_TCL) $(IMPL_PATH) $(SYNTH_DCP) $(XDC_FILE)
	cp $(XDC_FILE) $(IMPL_PATH) && \
	cp $(IMPL_TCL) $(IMPL_PATH) && \
	cd $(IMPL_PATH) && \
	vivado -m64 -mode batch -notrace -source $(IMPL_TCL)


#bitfile
BITFILE=$(IMPL_PATH)/$(TOP).bit
BITFILE_TCL=$(TOP)_bitfile.tcl

.PHONY: bitfile
bitfile: $(BITFILE)

$(BITFILE):	$(ROUTE_DCP) $(BITFILE_TCL)
	cp $(BITFILE_TCL) $(IMPL_PATH) && \
	cd $(IMPL_PATH) && \
	vivado -m64 -mode batch -notrace -log bitfile.log -source $(BITFILE_TCL)


PROGRAM_TCL=program_bf.tcl
program: 
	cp $(PROGRAM_TCL) $(IMPL_PATH) && \
	cd $(IMPL_PATH) && \
	vivado -mode batch -notrace -log program.log -source $(PROGRAM_TCL)


.PHONY: clean
clean:
	rm -rf $(SYNTH_PATH)
	rm -rf $(IMPL_PATH)
	

# keep intermediate files
.SECONDARY: