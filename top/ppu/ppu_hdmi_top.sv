module ppu_hdmi_top #(
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

    wire rst_clocks = btn[0];

    wire clk_ppu, clk_cpu;
    wire clk_hdmi_x5, clk_hdmi;
    wire rst_ppu, rst_cpu, rst_tdms, rst_hdmi;
    wire locked;
    wire [1:0] cpu_phase;

clocks  u_clocks(
    .CLK_125MHZ  (CLK_125MHZ  ),
    .rst_clocks  (rst_clocks  ),
    .clk_hdmi_x5 (clk_hdmi_x5 ),
    .clk_hdmi    (clk_hdmi    ),
    .clk_ppu     (clk_ppu     ),
    .clk_cpu     (clk_cpu     ),
    .cpu_phase    (cpu_phase    ),
    .locked      (locked      ),
    .rst_tdms    (rst_tdms    ),
    .rst_hdmi    (rst_hdmi    ),
    .rst_ppu     (rst_ppu     ),
    .rst_cpu     (rst_cpu     )
);

    assign  LED[0] = SW[0]; 
    assign  LED[1] = SW[1]; 
    assign  LED[2] = frame_sync; 
    assign  LED[3] = locked; 

    logic nmi, cpu_rw;
    logic [15:0] cpu_addr;
    wire [7:0] cpu_data_o;
    wire [7:0] cpu_data_i;

    cpu_sim 
    #(
        .SCROLLX_PER_FRAME (1 ),
        .SCROLLY_PER_FRAME (0 )
    )
    u_cpu_sim(
        .clk    (clk_cpu    ),
        .rst    (rst_cpu    ),
        .nmi    (nmi    ),
        .rw     (cpu_rw     ),
        .addr   (cpu_addr   ),
        .data_o (cpu_data_o ),
        .data_i (cpu_data_i )
    );

    // pulse cs for one ppu clock on tail end of cpu cycle
    wire cpu_ppu_cs = (cpu_phase==2) & (cpu_addr[15:13] == 3'h1);


    wire [2:0] cpu_ppu_addr = cpu_addr[2:0];

    logic [7:0] ppu_data_rd,ppu_data_wr;
    logic ppu_rd, ppu_wr;
    wire ppu_rw = !ppu_wr;

    logic [13:0] ppu_addr;
    logic [7:0] px_data;
    logic px_en, frame_sync, frame_trigger;
    ppu #(
        .EXTERNAL_FRAME_TRIGGER (1)
        )
    u_ppu(
        .clk        (clk_ppu        ),
        .rst        (rst_ppu        ),
        .cpu_rw     (cpu_rw     ),
        .cpu_cs     (cpu_ppu_cs     ),
        .cpu_addr   (cpu_ppu_addr   ),
        .cpu_data_i (cpu_data_o ),
        .ppu_data_i (ppu_data_rd ),
        .cpu_data_o (cpu_data_i ),
        .nmi        (nmi        ),
        .ppu_addr_o   (ppu_addr   ),
        .ppu_data_o (ppu_data_wr ),
        .ppu_rd     (ppu_rd     ),
        .ppu_wr     (ppu_wr     ),
        .px_data    (px_data    ),
        .px_en    (px_en    ),
        .frame_trigger (frame_trigger ),
        .frame_sync (frame_sync )
    );

    mmap u_mmap(
        .clk    (clk_ppu    ),
        .rst    (rst_ppu    ),
        .addr   (ppu_addr   ),
        .rw     (ppu_rw     ),
        .data_i (ppu_data_wr ),
        .data_o (ppu_data_rd )
    );


    logic [23:0] pal [63:0];
    initial $readmemh(`PALFILE, pal);

    wire [5:0] px_data_test = btn[3] ? {4'b0,SW} : px_data[5:0];
    wire [23:0] rgb_p = btn[2] ? {SW[1], 7'h0, SW[0], 15'h0} :
                        btn[1] ? {px_data[5:4], 6'h0, px_data[3:2], 6'h0, px_data[1:0], 6'h0} :
                        pal[px_data_test];


    logic [9:0] hx, hy;
    logic [23:0] rgb_h;
    
    hdmi_upscaler
    #(
        .ISCREEN_WIDTH (ISCREEN_WIDTH),
        .ISCREEN_HEIGHT (ISCREEN_HEIGHT),
        .IFRAME_WIDTH (IFRAME_WIDTH),
        .IFRAME_HEIGHT (IFRAME_HEIGHT),
        .OSCREEN_WIDTH (OSCREEN_WIDTH),
        .OSCREEN_HEIGHT (OSCREEN_HEIGHT),
        .OFRAME_WIDTH (OFRAME_WIDTH),
        .OFRAME_HEIGHT (OFRAME_HEIGHT),
        .IPIXEL_LATENCY (ISCREEN_WIDTH)
    )
    u_hdmi_upscaler (
        .clk_p     (clk_ppu     ),
        .rst_p     (rst_ppu       ),
        .clk_h     (clk_hdmi     ),
        .rst_h     (rst_hdmi       ),
        .rgb_p     (rgb_p     ),
       .new_frame (frame_trigger),
         .hx        (hx        ),
        .hy        (hy        ),
        .rgb_h     (rgb_h     )
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
        .clk_pixel_x5      (clk_hdmi_x5      ),
        .clk_pixel         (clk_hdmi         ),
        .reset             (rst_hdmi             ),
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


endmodule
