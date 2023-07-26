`timescale 1ns/1ps

module hdmi_upscale_tb #(
    // parameter ISCREEN_WIDTH =   9'd256,
    // parameter ISCREEN_HEIGHT =  9'd240,
    // parameter IFRAME_WIDTH =  9'd341,
    // parameter IFRAME_HEIGHT =  9'd262,
    // parameter OSCREEN_WIDTH =  10'd720,
    // parameter OSCREEN_HEIGHT =  10'd480,
    // parameter OFRAME_WIDTH =  10'd858,
    // parameter OFRAME_HEIGHT =  10'd525,

    parameter ISCREEN_WIDTH =   25,
    parameter ISCREEN_HEIGHT =  24,
    parameter IFRAME_WIDTH =  33,
    parameter IFRAME_HEIGHT =  26,
    parameter OSCREEN_WIDTH =  72,
    parameter OSCREEN_HEIGHT =  48,
    parameter OFRAME_WIDTH =  86,
    parameter OFRAME_HEIGHT =  53,

    // sim timing
    parameter real HDMI_CLK = 27.0,
    parameter real PPU_CLK = (0.5*HDMI_CLK*IFRAME_WIDTH)/OFRAME_WIDTH,
    parameter real PPU_HDMI_CLK_RATIO = PPU_CLK/HDMI_CLK,
    parameter real FRAME_TIME = 1000.0*OFRAME_WIDTH*OFRAME_HEIGHT/HDMI_CLK,
    parameter SIM_LENGTH = 1.25*FRAME_TIME
)();

    logic CLK_125MHZ, rst_clocks;
    initial begin

        $display("PPU_CLK %f", PPU_CLK);
        $display("HDMI_CLK %f", HDMI_CLK);
        $display("FRAME_TIME %f", FRAME_TIME);

        CLK_125MHZ = 0;
        rst_clocks=1;
        #20;
        rst_clocks=0;

        #SIM_LENGTH;
        // #1000000
        $finish;
    end
    always #4 CLK_125MHZ = ~CLK_125MHZ;

    wire clk_hdmi_x5, clk_hdmi, clk_ppu, clk_cpu;
    wire rst_p, rst_h, rst_cpu, rst_tdms;

    clocks #(
        .PPU_HDMI_CLK_RATIO (PPU_HDMI_CLK_RATIO)
    )
    u_clocks(
        .CLK_125MHZ (CLK_125MHZ ),
        .rst_clocks    (rst_clocks    ),
        .clk_hdmi_x5   (clk_hdmi_x5   ),
        .clk_hdmi   (clk_hdmi   ),
        .clk_ppu    (clk_ppu    ),
        .clk_cpu    (clk_cpu    ),
        .locked     (locked     ),
        .rst_tdms   (rst_tdms   ),
        .rst_hdmi   (rst_h   ),
        .rst_ppu    (rst_p    ),
        .rst_cpu    (rst_cpu    )
    );
    

    logic [23:0] rgb_p,rgb_h;
    logic [9:0] hx, hy;
    logic new_frame;

    hdmi_upscaler
    #(
        .ISCREEN_WIDTH (ISCREEN_WIDTH),
        .ISCREEN_HEIGHT (ISCREEN_HEIGHT),
        .IFRAME_WIDTH (IFRAME_WIDTH),
        .IFRAME_HEIGHT (IFRAME_HEIGHT),
        .OSCREEN_WIDTH (OSCREEN_WIDTH),
        .OSCREEN_HEIGHT (OSCREEN_HEIGHT),
        .OFRAME_WIDTH (OFRAME_WIDTH),
        .OFRAME_HEIGHT (OFRAME_HEIGHT)
        .IPIXEL_LATENCY (1)                 // first pixel of new frame will be IPIXEL_LATENCY clocks after new_frame is asserted
    )
    u_hdmi_upscaler (
        .clk_p     (clk_ppu     ),
        .rst_p     (rst_p       ),
        .clk_h     (clk_hdmi     ),
        .rst_h     (rst_h       ),
        .rgb_p     (rgb_p     ),
        .aux        (2'b00),
        .new_frame (new_frame),
        .hx        (hx        ),
        .hy        (hy        ),
        .rgb_h     (rgb_h     )
    );


    logic [8:0] px, py;

    wire last_px = (px == IFRAME_WIDTH-1);
    wire [8:0] px_next = last_px ? 0 : px + 1'b1;
    wire [8:0] py_next = last_px ? py+1 : py;
    always_ff @(posedge clk_ppu) begin
        if (rst_p) begin
            px <=0;
            py <=0;
        end
        else 
        begin
            px <= new_frame ? 0 : px_next;
            py <= new_frame ? 0 : py_next;
        end
    end

    assign rgb_p = (px==0 || py==0 || px==ISCREEN_WIDTH-1 || py==ISCREEN_HEIGHT-1) ? 24'hffffff :
                (px[0] ^ py[0]) ? {px[7:0], py[7:0], 8'h0} : 24'h0;


    initial begin
        // $dumpfile(`DUMP_WAVE_FILE);
        $dumpvars(0, hdmi_upscale_tb);
    end


endmodule