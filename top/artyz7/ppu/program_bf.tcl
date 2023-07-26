open_hw
connect_hw_server
get_hw_targets
current_hw_target [get_hw_targets]
open_hw_target
set_property PROGRAM.FILE {/home/jpdoane/dev/2c02/top/artyz7/ppu/ppu_hdmi_top_impl/ppu_hdmi_top.bit} [get_hw_devices xc7z010_1]
program_hw_devices [get_hw_devices xc7z010_1]
refresh_hw_device [lindex [get_hw_devices xc7z010_1] 0]
disconnect_hw_server
close_hw
