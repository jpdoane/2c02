`timescale 1ns/1fs

module clocks
    #(
        parameter real MASTER_CLK_PERIOD = 8.0,            // 125 MHZ
        parameter real HDMI_MASTER_CLK_RATIO = 27.0/125.0,   // 27 MHZ
        parameter real PPU_HDMI_CLK_RATIO = 341.0/1716.0,     // 5.36538461538 MHz
        parameter SIMULATE_HDMI5x = 0                       // disable 5x clock for sim
    )
    (
    input         CLK_125MHZ,
    input         rst_clocks,
    output        clk_hdmi_x5,    
    output        clk_hdmi,    
    output        clk_ppu,     
    output        clk_cpu,     
    output        [1:0] cpu_phase,
    output        locked,
    output        rst_tdms,
    output        rst_hdmi,
    output        rst_ppu,
    output        rst_cpu
    );

logic locked1;
logic [1:0] cpu_cnt3;
wire cpu_en = (cpu_cnt3 == 2'd2 );
assign cpu_phase = cpu_cnt3;

always_ff @(posedge clk_ppu)
begin
    if (rst_ppu) cpu_cnt3 <= 0;
    else cpu_cnt3 <= cpu_en ? 0 : cpu_cnt3 + 1;
end

`ifdef SYNTHESIS
    mmcm_hdmi u_mmcm_hdmi
    (
    .clk_hdmi_px(clk_hdmi),
    .clk_hdmi_px5(clk_hdmi_x5),
    .reset(rst_clocks), 
    .locked(locked1),
    .clk_125(CLK_125MHZ)
    );

    mmcm_ppu_from_hdmi u_mmcm_ppu_from_hdmi(
        .clk_ppu  (clk_ppu  ),
        .reset    (~locked1    ),
        .locked   (locked   ),
        .clk_hdmi (clk_hdmi )
    );

    BUFGCE BUFGCE_cpu (
    .O(clk_cpu),
    .CE(cpu_en),
    .I(clk_ppu)
    );

    // BUFGCE BUFGCE_cpum2 (
    // .O(clk_cpum2),
    // .CE(cpum2_en),
    // .I(clk_ppu)
    // );


`else
    logic locked_r, clk_hdmi_r, clk_hdmi_x5_r, clk_ppu_r;
    logic clk_cpu_r; //, clk_cpum2_r;
    // simulate clocks

    initial begin
        locked1 = 0;
        locked_r = 0;
        clk_hdmi_r = 0;
        clk_hdmi_x5_r = 0;
        clk_ppu_r = 0;
        clk_cpu_r = 0;
        // clk_cpum2_r = 0;
    end

    always @(rst_clocks) begin
        clk_hdmi_r = 0;
        clk_hdmi_x5_r = 0;
        locked1 = 0;
        if (~rst_clocks) locked1 = #200 1;
    end

    always @(locked1) begin
        clk_ppu_r = 0;
        locked_r = 0;
        if (locked1) locked_r = #500 1;
    end

    localparam real HDMI_CLK_HALFPERIOD = MASTER_CLK_PERIOD/(HDMI_MASTER_CLK_RATIO*2);
    localparam real HDMI5x_CLK_HALFPERIOD = HDMI_CLK_HALFPERIOD/5;
    localparam real PPU_CLK_HALFPERIOD = HDMI_CLK_HALFPERIOD/PPU_HDMI_CLK_RATIO;

    localparam real ACTUAL_CLOCK_RATIO = HDMI_CLK_HALFPERIOD/PPU_CLK_HALFPERIOD;

    always #HDMI_CLK_HALFPERIOD     clk_hdmi_r = ~clk_hdmi_r;
    always #PPU_CLK_HALFPERIOD      clk_ppu_r = ~clk_ppu_r;

    generate
    if (SIMULATE_HDMI5x) begin
        always clk_hdmi_x5_r = #HDMI5x_CLK_HALFPERIOD ~clk_hdmi_x5_r;
    end
    endgenerate

	always_ff @(posedge clk_ppu)
	begin
        clk_cpu_r <= cpu_en;
        // clk_cpum2_r <= cpum2_en;
	end

    assign locked = locked_r;
    assign clk_hdmi = clk_hdmi_r;
    assign clk_hdmi_x5 = clk_hdmi_x5_r;
    assign clk_ppu = clk_ppu_r;
	assign clk_cpu = clk_cpu_r;
	// assign clk_cpum2 = clk_cpum2_r;

`endif


	assign rst_tdms = ~locked1;
	assign rst_hdmi = ~locked1;
	assign rst_ppu = ~locked;

    logic [7:0] rst_cpu_sr;
	always_ff @(posedge clk_ppu) begin
        if (rst_ppu) rst_cpu_sr <= 8'hff;
        else rst_cpu_sr <= rst_cpu_sr << 1;
    end
    assign rst_cpu = rst_cpu_sr[7];

endmodule