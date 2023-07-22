
module test_hdmi_upscale_top #(
    parameter ISCREEN_WIDTH =   9'd256,
    parameter ISCREEN_HEIGHT =  9'd240,
    parameter IFRAME_WIDTH =  9'd341,
    parameter IFRAME_HEIGHT =  9'd262,
    parameter OSCREEN_WIDTH =  10'd720,
    parameter OSCREEN_HEIGHT =  10'd480,
    parameter OFRAME_WIDTH =  10'd858,
    parameter OFRAME_HEIGHT =  10'd525
)
(
  input CLK_125MHZ,

  input [1:0] SW,
  input [3:0] btn,
  output [3:0] LED,

  // HDMI output
  output [2:0] HDMI_TX,
  output [2:0] HDMI_TX_N,
  output HDMI_CLK,
  output HDMI_CLK_N
);


    wire hdmi_locked;
    wire ppu_locked;
    wire clk_rst = btn[0];

    wire rst0 = ~ppu_locked || ~hdmi_locked; 

    logic rst_p, rst_p_r, rst_p_rr;
    always_ff @(posedge clk_ppu) begin
        rst_p_rr <= rst0;
        rst_p_r <= rst_p_rr;
        rst_p <= rst_p_rr | rst_p_r | rst_p_r;
    end

    logic rst_h, rst_h_r, rst_h_rr;
    always_ff @(posedge clk_hdmi) begin
        rst_h_rr <= rst_p;
        rst_h_r <= rst_h_rr;
        rst_h <= rst_h_rr | rst_h_r | rst_h_r;
    end



    logic new_frame;

    assign  LED[0] = SW[0]; 
    assign  LED[1] = new_frame; 
    assign  LED[2] = hdmi_locked; 
    assign  LED[3] = ppu_locked; 

    wire clk_tmds;
    wire clk_hdmi;
    wire clk_ppu;

    mmcm_hdmi u_mmcm_hdmi(
        .clk_hdmi_px  (clk_hdmi    ),
        .clk_hdmi_px5 (clk_tmds ),
        .reset        (clk_rst          ),
        .locked       (hdmi_locked       ),
        .clk_125      (CLK_125MHZ   )
    );

    clk_ppu_from_hdmi u_clk_ppu_from_hdmi(
        .clk_ppu  (clk_ppu  ),
        .reset    (clk_rst    ),
        .locked   (ppu_locked   ),
        .clk_hdmi (clk_hdmi )
    );


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
        .aux       (SW),
        .rgb_p     (rgb_p     ),
        .px        (px        ),
        .py        (py        ),
        .hx        (hx        ),
        .hy        (hy        ),
        .rgb_h     (rgb_h     ),
        .stall     (stall )
    );


    ///
    /// hmdi
    ///
    logic [2:0] tmds;
    logic tmds_clock;

    hdmi_noaudio 
    #(
        .VIDEO_ID_CODE(2),
        .BIT_WIDTH  (10),
        .BIT_HEIGHT (10),
        .VIDEO_REFRESH_RATE ( 59.94 )
    )
    u_hdmi(
        .clk_pixel_x5      (clk_tmds      ),
        .clk_pixel         (clk_hdmi         ),
        .reset             (rst_h             ),
        .rgb               (rgb_h               ),
        .tmds              (tmds              ),
        .tmds_clock        (tmds_clock        ),
        .cx                 (hx        ),
        .cy                 (hy        )
    );


    genvar i;
    generate
        for (i = 0; i < 3; i++)
        begin: obufds_gen
            OBUFDS #(.IOSTANDARD("TMDS_33")) obufds (.I(tmds[i]), .O(HDMI_TX[i]), .OB(HDMI_TX_N[i]));
        end
        OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_clock(.I(tmds_clock), .O(HDMI_CLK), .OB(HDMI_CLK_N));
    endgenerate


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



endmodule
