module hdmi_upscaler #(
    parameter  ISCREEN_WIDTH = 256,
    parameter  ISCREEN_HEIGHT = 240,
    parameter  IFRAME_WIDTH = 341,
    parameter  IFRAME_HEIGHT = 262,
    parameter  OSCREEN_WIDTH = 720,
    parameter  OSCREEN_HEIGHT = ISCREEN_HEIGHT*SUB_Y,
    parameter  OFRAME_WIDTH = 858,
    parameter  OFRAME_HEIGHT = ISCREEN_HEIGHT*SUB_Y,
    parameter  SUB_X = 2,
    parameter  SUB_Y = 2,
    parameter  OSCREEN_SHIFT = (OSCREEN_WIDTH - ISCREEN_WIDTH*SUB_X) >> 1,
    parameter  IPIXEL_LATENCY = 1                 // first pixel of new frame will be IPIXEL_LATENCY clocks after new_frame is asserted
    )
(
  input logic clk_p,                // ppu pixel clock
  input logic rst_p,                // clk_p domain reset
  input logic clk_h,                // hdmi pixel clock
  input logic rst_h,                // clk_h domain reset
  input logic [23:0] rgb_p,         // rgb from ppu
  output logic new_frame,           // signals start of each frame, first pixel should arrive IPIXEL_LATENCY clocks later
  output logic [9:0] hx, hy,        // ouput hdmi counters
  output logic [23:0] rgb_h        // rgb to hdmi
);

    // icycles per frame
    localparam int ICYCLES_MULTIFRAME = OFRAME_HEIGHT*IFRAME_WIDTH;
    localparam int ICYCLES_EVEN = ICYCLES_MULTIFRAME >> 1;                  //icycles per even frame
    localparam int ICYCLES_ODD = ICYCLES_EVEN + ICYCLES_MULTIFRAME[0];      //icycles per odd frame

    // assert(OFRAME_HEIGHT >= IFRAME_HEIGHT*SUB_Y);

    logic [23:0] ibuf [0:ISCREEN_WIDTH-1];     // input buffer from ppu
    logic [23:0] obuf [0:ISCREEN_WIDTH-1];     // playback buffer to hdmi

// clk_p domain (slower)
//

    // parity bit to track even/odd frames
    logic frame_odd = 0;
    logic p_sync = 1;
    logic [17:0] pcnt = 0;
    logic [8:0] px = 0;
    
    // signal external rendering system
    assign new_frame = frame_odd ? pcnt == ICYCLES_ODD-IPIXEL_LATENCY : pcnt == ICYCLES_EVEN-IPIXEL_LATENCY;
    // signal internal counter to roll over
    wire new_pframe = frame_odd ? pcnt == ICYCLES_ODD-1 : pcnt == ICYCLES_EVEN-1;

    // manage p coutner and buffer incoming pixels
    int i;
    always_ff @(posedge clk_p) begin
        if (rst_p) begin
            for (i = 0; i < ISCREEN_WIDTH; i++) ibuf[i] <= 24'hff0000;

            pcnt<= 0;
            px <= 0;
            frame_odd <= 0;
            p_sync <= 1;

        end else begin
            for (i = 0; i < ISCREEN_WIDTH; i++) ibuf[i] <= ibuf[i];
            if (px < ISCREEN_WIDTH) ibuf[px] <= rgb_p;

            //count x position (for filling scanline buffer)
            px <= new_pframe || (px==IFRAME_WIDTH-1) ? 0 : px + 1;
            //count cycles (for triggering new frame)
            pcnt <= new_pframe ? 0 : pcnt + 1;

            //track even/odd frames (due to different in cycles/frame)
            frame_odd <= new_pframe ? ~frame_odd : frame_odd;

            // initally high, this goes low once first line is buffered,
            // signaling output hdmi counters to start reading buffer
            // if all counts and clocks are consistent, input and out frames should remain synced
            p_sync <= p_sync && ~(px==ISCREEN_WIDTH);

        end
    end
    
// clk_h domain (faster)
//

    // pixel and subpixel counters for output frame
    logic [7:0] hx_idx;
    wire  [7:0] hx_idx_nxt = hx_idx == ISCREEN_WIDTH-1 ? 0 : hx_idx + 1;
    logic sub_hx,sub_hy;

    logic draw_on;
    wire pen_down = hx == OSCREEN_SHIFT;
    wire pen_up = hx == OSCREEN_SHIFT+ISCREEN_WIDTH*SUB_X;
    
    logic h_sync, h_sync_r, h_sync_rr;
    wire new_hline = hx == OFRAME_WIDTH - 1;
    wire new_hframe = h_sync_rr || (hy == OFRAME_HEIGHT - 1 && new_hline);

    always_ff @(posedge clk_h)
    begin
        if (rst_h)
        begin
            hx <= 0;
            hy <= 0;
            sub_hx <= 0;
            sub_hy <= 0;
            hx_idx <= 0;
            draw_on <= 0;

            h_sync <= 1;
            h_sync_r <= 1;
            h_sync_rr <= 1;
        end
        else
        begin

            h_sync <= p_sync;
            h_sync_r <= h_sync;
            h_sync_rr <= h_sync_r;

            draw_on <= (draw_on || pen_down) && ~pen_up;

            hx <= new_hframe || new_hline ? 0 : hx + 1;
            hy <= new_hframe ? 0 : new_hline ? hy + 1 : hy;

            sub_hx <= draw_on ? sub_hx + 1 : 0;
            sub_hy <= new_hframe ? 0: new_hline ? sub_hy + 1 : sub_hy;

            hx_idx <=   new_hframe || new_hline ? 0 :
                        draw_on && (sub_hx == SUB_X-1) ? hx_idx_nxt :
                        hx_idx;

            rgb_h <= draw_on ? rgb_buf : 0;
        end
    end

    // load new scanline from input buffer every SUB_Y lines 
    wire load_iline = new_hframe || (new_hline && (sub_hy == SUB_Y-1));
    always_ff @(posedge clk_h) begin
        for (i = 0; i < ISCREEN_WIDTH; i++)
        begin
            if (rst_h) obuf[i] <= 0;
            else obuf[i] <= load_iline ? ibuf[i] : obuf[i];
        end
    end

    wire [23:0] rgb_buf = obuf[hx_idx];


endmodule
