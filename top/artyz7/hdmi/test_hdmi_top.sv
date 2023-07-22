module test_hdmi_top
(
  input CLK_125MHZ,

  input [1:0] SW,
  input [3:0] btn,
  output [3:0] LED,

  // HDMI output
  output [2:0] HDMI_TX,
  output [2:0] HDMI_TX_N,
  output HDMI_CLK,
  output HDMI_CLK_N,
  input HDMI_CEC,
  inout HDMI_SDA,
  inout HDMI_SCL,
  input HDMI_HPD
);

    wire clk_pixel_x5;
    wire clk_pixel;
    wire clk_cpu;


    wire rst = btn[0]; 
    wire locked;

    // clocks u_clocks(
    //     .clk_cpu    (clk_cpu    ),
    //     .clk_ppu    (clk_pixel    ),
    //     .clk_hdmi   (clk_pixel_x5   ),
    //     .rst        (rst        ),
    //     .locked     (locked     ),
    //     .CLK_125MHZ (CLK_125MHZ )
    // );

    mmcm_hdmi u_mmcm_hdmi(
        .clk_hdmi_px  (clk_pixel    ),
        .clk_hdmi_px5 (clk_pixel_x5 ),
        .reset        (rst          ),
        .locked       (locked       ),
        .clk_125      (CLK_125MHZ   )
    );


    assign  LED[0] = SW[0]; 
    assign  LED[1] = SW[1]; 
    assign  LED[3] = locked; 

////
/// audio
////
    wire clk_audio;
    logic [10:0] counter = 1'd0;
    always_ff @(posedge clk_pixel)
    begin
        // ????
        counter <= counter == 11'd1546 ? 1'd0 : counter + 1'd1;
    end
    assign clk_audio = clk_pixel && counter == 11'd1546;


    localparam AUDIO_BIT_WIDTH = 16;
    localparam AUDIO_RATE = 48000;
    localparam WAVE_RATE = 480;

    logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word;
    logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word_dampened; // This is to avoid giving you a heart attack -- it'll be really loud if it uses the full dynamic range.
    assign audio_sample_word_dampened = audio_sample_word >> 9;

 
    ///
    /// hmdi
    ///
    logic [23:0] rgb;
    logic [9:0] cx, cy;
    logic [2:0] tmds;
    logic tmds_clock;

    logic [9:0] frame_width, frame_height, screen_width, screen_height;
    hdmi 
    #(
        .VIDEO_ID_CODE(2),
        .BIT_WIDTH  (10),
        .BIT_HEIGHT (10),
        .VIDEO_REFRESH_RATE ( 60.0 ),
        .AUDIO_RATE(AUDIO_RATE),
        .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
        .VENDOR_NAME ({"JPD_NES", 8'd0} )
    )
    u_hdmi(
        .clk_pixel_x5      (clk_pixel_x5      ),
        .clk_pixel         (clk_pixel         ),
        .clk_audio         (clk_audio         ),
        .reset             (rst             ),
        .rgb               (rgb               ),
        .audio_sample_word ('{audio_sample_word_dampened,  audio_sample_word_dampened} ),
        .tmds              (tmds              ),
        .tmds_clock        (tmds_clock        ),
        .cx                 (cx        ),
        .cy                 (cy        ),
        .frame_width       (frame_width       ),
        .frame_height      (frame_height      ),
        .screen_width      (screen_width      ),
        .screen_height     (screen_height     )
    );


    genvar i;
    generate
        for (i = 0; i < 3; i++)
        begin: obufds_gen
            OBUFDS #(.IOSTANDARD("TMDS_33")) obufds (.I(tmds[i]), .O(HDMI_TX[i]), .OB(HDMI_TX_N[i]));
        end
        OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_clock(.I(tmds_clock), .O(HDMI_CLK), .OB(HDMI_CLK_N));
    endgenerate


    always_ff @(posedge clk_pixel) begin
        rgb <= SW[1] ? {8'd0, cx[8:1], cy[8:1]} : {cx[8:1], 8'd0, cy[8:1]};
    end

endmodule
