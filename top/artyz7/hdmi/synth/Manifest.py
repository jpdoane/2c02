action = "synthesis"

syn_device = "xc7z010"
syn_grade = "-1"
syn_package = "clg400"
syn_top = "test_hdmi_upscale_top"
syn_project = "test_hdmi_upscale_top"
syn_tool = "vivado"

files = [
    "../test_hdmi_upscale_top.sv",
    "../../artyz7.xdc"
]

modules = {
  "local" : [ "../../../../modules/hdmi", "../../../../modules/clocks" ],
}


