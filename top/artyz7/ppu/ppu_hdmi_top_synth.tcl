# 
# Synthesis run script generated by Vivado
# 

set TIME_start [clock seconds] 
proc create_report { reportName command } {
  set status "."
  append status $reportName ".fail"
  if { [file exists $status] } {
    eval file delete [glob $status]
  }
  send_msg_id runtcl-4 info "Executing : $command"
  set retval [eval catch { $command } msg]
  if { $retval != 0 } {
    set fp [open $status w]
    close $fp
    send_msg_id runtcl-5 warning "$msg"
  }
}

proc load_sources {file_list} {
}

proc load_constraints {file_list} {
    set fh [open $file_list r]
    while {[gets $fh filename] >= 0} {
        read_verilog -library xil_defaultlib -sv $filename
        puts "Read file: $filename"
    }
    close $fh
}

create_project -in_memory -part xc7z010clg400-1

set_param project.singleFileAddWarning.threshold 0
set_param project.compositeFile.enableAutoGeneration 0
set_param synth.vivado.isSynthRun true
#set_property webtalk.parent_dir /home/jpdoane/dev/2c02/top/artyz7/ppu/vivado_proj/vivado.cache/wt [current_project]
#set_property parent.project_path /home/jpdoane/dev/2c02/top/artyz7/ppu/vivado_proj/vivado.xpr [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property target_language Verilog [current_project]
set_property ip_output_repo /home/jpdoane/dev/2c02/top/artyz7/ppu/vivado_proj/vivado.cache/ip [current_project]
set_property ip_cache_permissions {read write} [current_project]

# load verilog source
set fh [open "sources.tcl" r]
while {[gets $fh filename] >= 0} {
    read_verilog -library xil_defaultlib -sv $filename
    puts "Read file: $filename"
}
close $fh

# Mark all dcp files as not used in implementation to prevent them from being
# stitched into the results of this synthesis run. Any black boxes in the
# design are intentionally left as such for best results. Dcp files will be
# stitched into the design at a later time, either when this synthesis run is
# opened, or when it is stitched into a dependent implementation run.
foreach dcp [get_files -quiet -all -filter file_type=="Design\ Checkpoint"] {
  set_property used_in_implementation false $dcp
}

# load constraints
set fh [open "constrainsts.tcl" r]
while {[gets $fh filename] >= 0} {
    read_xdc $filename
    set_property used_in_implementation false [get_files $filename]
    puts "Read constriant: $filename"
}
close $fh

set_param ips.enableIPCacheLiteLoad 0
close [open __synthesis_is_running__ w]

synth_design -top ppu_hdmi_top -part xc7z010clg400-1 -verilog_define ROM_PATH="/home/jpdoane/dev/2c02/roms/smb/" -verilog_define PALFILE="/home/jpdoane/dev/2c02/roms/nes.pal" \

# disable binary constraint mode for synth run checkpoints
set_param constraints.enableBinaryConstraints false
write_checkpoint -force -noxdef ppu_hdmi_top.dcp
create_report "synth_1_synth_report_utilization_0" "report_utilization -file ppu_hdmi_top_utilization_synth.rpt -pb ppu_hdmi_top_utilization_synth.pb"
file delete __synthesis_is_running__
close [open __synthesis_is_complete__ w]
