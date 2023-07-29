action = "simulation"
sim_tool = "iverilog"
sim_top = "ppu_tb"

iverilog_opt = "-g2012 -D\'ROM_PATH=\"../../../roms/smb/\"\'   -D\'PALFILE=\"../../../roms/nes.mem\"\'"
sim_post_cmd = "vvp ppu_tb.vvp"

files = [
    "../ppu_tb.sv", 
    "../video_png.sv" 
]

modules = {
  "local" : [ "../../../modules/ppu", "../../../modules/clocks" ],
}

