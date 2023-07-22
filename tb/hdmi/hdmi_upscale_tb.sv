`timescale 1us/1ns


module hdmi_upscale_tb #(
    // parameter ISCREEN_WIDTH =   9'd256,
    // parameter ISCREEN_HEIGHT =  9'd240,
    // parameter IFRAME_WIDTH =  9'd341,
    // parameter IFRAME_HEIGHT =  9'd262,
    // parameter SUB_X =  2,
    // parameter SUB_Y =  2,
    // parameter OSCREEN_WIDTH =  10'd720,
    // parameter OSCREEN_HEIGHT =  10'd480,
    // parameter OFRAME_WIDTH =  10'd858,
    // parameter OFRAME_HEIGHT =  10'd525,
    // parameter  NEWFRAME_LINE = OFRAME_HEIGHT-3 ,                                 // new_frame will be high for duration of this output scan line
    // parameter OSCANLINE_PERIOD = 1000.0,
    // parameter ISCANLINE_PERIOD = SUB_Y*OSCANLINE_PERIOD,
    // parameter PPU_CLK_HALFPERIOD = ISCANLINE_PERIOD/IFRAME_WIDTH/2,
    // parameter HMDI_CLK_HALFPERIOD = OSCANLINE_PERIOD/OFRAME_WIDTH/2,
    // parameter SIM_LENGTH = OSCANLINE_PERIOD*10

    parameter ISCREEN_WIDTH =   25,
    parameter ISCREEN_HEIGHT =  24,
    parameter IFRAME_WIDTH =  33,
    parameter IFRAME_HEIGHT =  26,
    parameter OSCREEN_WIDTH =  72,
    parameter OSCREEN_HEIGHT =  48,
    parameter OFRAME_WIDTH =  86,
    parameter OFRAME_HEIGHT =  53,

    // clocks
    parameter OSCANLINE_PERIOD = 1000.0,
    parameter ISCANLINE_PERIOD = 2*OSCANLINE_PERIOD,
    parameter PPU_CLK_HALFPERIOD = ISCANLINE_PERIOD/IFRAME_WIDTH/2,
    parameter HMDI_CLK_HALFPERIOD = OSCANLINE_PERIOD/OFRAME_WIDTH/2,
    parameter SIM_LENGTH = OSCANLINE_PERIOD*OFRAME_HEIGHT*5.1
)();

    logic clk_tmds;
    logic clk_hdmi;
    logic clk_ppu;
    logic rst_p,rst_h;
    logic px_en;
    
    initial begin
        clk_tmds =0;
        clk_hdmi =0;
        clk_ppu =0;
        rst_p = 1;
        rst_h = 1;
        #PPU_CLK_HALFPERIOD
        #PPU_CLK_HALFPERIOD
        #PPU_CLK_HALFPERIOD
        #PPU_CLK_HALFPERIOD
        rst_p = 1;
        rst_h = 1;

        #SIM_LENGTH;
        $finish;

    end

    always #PPU_CLK_HALFPERIOD clk_ppu = ~clk_ppu;
    always #HMDI_CLK_HALFPERIOD clk_hdmi = ~clk_hdmi;

    logic [23:0] rgb_p,rgb_h;
    logic [8:0] px, py;
    logic [9:0] hx, hy;
    logic stall;

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
    )
    u_hdmi_upscaler (
        .clk_p     (clk_ppu     ),
        .rst_p     (rst_p       ),
        .clk_h     (clk_hdmi     ),
        .rst_h     (rst_h       ),
        .rgb_p     (rgb_p     ),
        .aux        (2'b11),
        .px        (px        ),
        .py        (py        ),
        .hx        (hx        ),
        .hy        (hy        ),
        .rgb_h     (rgb_h     ),
        .stall     (stall     )
    );



    wire last_px = (px == IFRAME_WIDTH-1);
    wire last_line = (py == IFRAME_HEIGHT-1);
    wire [8:0] px_next = last_px ? 0 : px + 1'b1;
    wire [8:0] py_next = ~last_px ? py : last_line ? 0 : py + 1'b1;
    always_ff @(posedge clk_ppu) begin
        if (rst_p) begin
            px <=0;
            py <=0;
        end
        else 
        begin
            px <= stall ? px : px_next;
            py <= stall ? py : py_next;
        end
    end

    assign rgb_p = (px==0 || py==0 || px==ISCREEN_WIDTH-1 || py==ISCREEN_HEIGHT-1) ? 24'hffffff :
                (px[0] ^ py[0]) ? {px[7:0], py[7:0], 8'h0} : 24'h0;



    initial begin
        // $dumpfile(`DUMP_WAVE_FILE);
        $dumpvars(0, hdmi_upscale_tb);
    end


endmodule