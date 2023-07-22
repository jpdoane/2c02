action = "simulation"
sim_tool = "iverilog"
sim_top = "hdmi_upscale_tb"

iverilog_opt = "-g2012"
sim_post_cmd = "vvp hdmi_upscale_tb.vvp"

files = [
    "../hdmi_upscale_tb.sv"
]

modules = {
  "local" : [ "../../../modules/hdmi" ],
}

