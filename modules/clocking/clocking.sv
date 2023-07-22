`timescale 1ps/1ps

// https://www.nesdev.org/wiki/Cycle_reference_chart#Clock_rates
// NES uses a 21.477272 MHz master clock, with div4 to obtain ppu pixel clock
// however the HDMI tmds signals are clocked at 5x pixel clock
// so we will use an MMCM to get a 26.84659MHz clock (21.477272 * 5/4)
// and divide the ppu and cpu clocks from that

module clocks
    (
    input         CLK_125MHZ,
    input         rst,
    output        clk_hdmi,    
    output        clk_ppu,     
    output        clk_cpu,     
    output        locked
    );

    // clk_mmcm clk_mmcm_u
    // (
    // .clk_master(clk_hdmi),
    // .reset(rst), 
    // .locked(locked),
    // .clk_125MHz(CLK_125MHZ)
    // );


    clk_640x480 clk_640x480_u
    (
    .clk_pixel(clk_ppu),
    .clk_pixel5(clk_hdmi),
    .reset(rst), 
    .locked(locked),
    .clk_125MHz(CLK_125MHZ)
    );

    logic [1:0] count3;
    // logic [3:0] count15;
    logic clk_div3_en;

    // BUFGCE BUFGCE_ppu (
    // .O(clk_ppu),
    // .CE(clk_div5_en),
    // .I(clk_hdmi)
    // );

    BUFGCE BUFGCE_cpu (
    .O(clk_cpu),
    .CE(clk_div3_en),
    .I(clk_ppu)
    );

	always_ff @(posedge clk_hdmi)
	begin
        if (rst) begin
            clk_div3_en <= 0;
            count3 <= 0;
        end else begin
            count3       <= (count3 == 2'd2 )   ? 2'd0 : count3 + 1'b1;
            clk_div3_en  <= (count3 == 2'd2 )   ? 1'b1 : 1'b0;
		end
	end

endmodule