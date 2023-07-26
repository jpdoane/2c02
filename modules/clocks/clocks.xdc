create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { CLK_125MHZ }];#set

create_generated_clock -name clk_hdmi -source [get_ports { CLK_125MHZ }]
                        -divide_by 125 -multiply_by 27 
                        [get_pins u_clocks/u_mmcm_hdmi/MMCME2_ADV/CLKOUT0]

create_generated_clock -name clk_hdmix5  -source [get_ports { CLK_125MHZ }]
                        -divide_by 25 -multiply_by 27 
                        [get_pins u_clocks/u_mmcm_hdmi/MMCME2_ADV/CLKOUT1]

create_generated_clock -name clk_ppu -source [get_pins u_clocks/u_mmcm_hdmi/MMCME2_ADV/CLKOUT0]
                        -divide_by 156 -multiply_by 31 
                        [get_pins u_clocks/u_mmcm_ppu_from_hdmi/MMCME2_ADV/CLKOUT0]

create_clock -name clk_cpu -source [get_pins u_clocks/u_mmcm_ppu_from_hdmi/MMCME2_ADV/CLKOUT0]
                                -edges {1 2 7} [get_pins u_clocks/BUFGCE_cpu/O]

create_clock -name clk_cpum2 -source [get_pins u_clocks/u_mmcm_ppu_from_hdmi/MMCME2_ADV/CLKOUT0]
                                -edges {5 6 11} [get_pins u_clocks/BUFGCE_cpum2/O]


#relax timing from slow ppu clock to fast hdmi clock
set_max_delay 10.0 -from clk_ppu -to clk_hdmi
