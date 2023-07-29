
include ../../inc/make.paths

TOP=ppu_tb
HDL_SOURCE = $(CLK_SOURCE) $(HDMI_SOURCE) $(PPU_SOURCE) video_png.sv $(TOP).sv
CUSTOMSIMARGS=-D'PALFILE="$(PROJ_ROOT)/roms/nes.mem"' -D'ROM_PATH="$(PROJ_ROOT)/roms/smb/"'

include ../../inc/make.sim

