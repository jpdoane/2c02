create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} \
                         [get_ports CLK_125MHZ]

create_generated_clock -name clk_hdmi -source [get_ports CLK_125MHZ] \
                        -divide_by 125 -multiply_by 27  \
                        [get_pins u_clocks/u_mmcm_hdmi/mmcm_adv_inst/CLKOUT0]

create_generated_clock -name clk_hdmix5  -source [get_ports CLK_125MHZ] \
                        -divide_by 25 -multiply_by 27 \
                        [get_pins u_clocks/u_mmcm_hdmi/mmcm_adv_inst/CLKOUT1]

create_generated_clock -name clk_ppu -source [get_pins u_clocks/u_mmcm_hdmi/mmcm_adv_inst/CLKOUT0] \
                        -divide_by 156 -multiply_by 31  \
                        [get_pins u_clocks/u_mmcm_ppu_from_hdmi/mmcm_adv_inst/CLKOUT0]

create_generated_clock -name clk_cpu -source [get_pins u_clocks/u_mmcm_ppu_from_hdmi/mmcm_adv_inst/CLKOUT0] \
                                -edges {1 2 7} [get_pins u_clocks/BUFGCE_cpu/O]

# create_generated_clock -name clk_cpum2 -source [get_pins u_clocks/u_mmcm_ppu_from_hdmi/mmcm_adv_inst/CLKOUT0] \
#                                 -edges {1 2 7} [get_pins u_clocks/BUFGCE_cpum2/O]


# relax timing from ppu clock to hdmi clock, since these clocks will drift in phase and timing is not critical
set_multicycle_path 2 -setup -from [get_clocks clk_ppu] -to [get_clocks clk_hdmi]
set_multicycle_path 2 -hold -from [get_clocks clk_ppu] -to [get_clocks clk_hdmi]

# relax timing between ppu clock and cpu
set_multicycle_path 3 -setup -from [get_clocks clk_cpu] -to [get_clocks clk_ppu]
set_multicycle_path 2 -hold -end -from [get_clocks clk_cpu] -to [get_clocks clk_ppu]
# set_multicycle_path 3 -setup -from [get_clocks clk_cpum2] -to [get_clocks clk_ppu]
# set_multicycle_path 2 -hold -end -from [get_clocks clk_cpum2] -to [get_clocks clk_ppu]

set_multicycle_path 3 -setup -start -from [get_clocks clk_ppu] -to [get_clocks clk_cpu] 
set_multicycle_path 2 -hold -from [get_clocks clk_ppu] -to [get_clocks clk_cpu]
# set_multicycle_path 3 -setup -start -from [get_clocks clk_ppu] -to [get_clocks clk_cpum2] 
# set_multicycle_path 2 -hold -from [get_clocks clk_ppu] -to [get_clocks clk_cpum2]