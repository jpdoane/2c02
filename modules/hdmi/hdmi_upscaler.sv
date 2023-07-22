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
    parameter  OSCREEN_SHIFT = (OSCREEN_WIDTH - ISCREEN_WIDTH*SUB_X) >> 1
    )
(
  input logic clk_p,                // ppu pixel clock
  input logic rst_p,                // clk_p domain reset
  input logic clk_h,                // hdmi pixel clock
  input logic rst_h,                // clk_h domain reset
  input logic [1:0] aux,
  input logic [23:0] rgb_p,         // rgb from ppu
  input logic [8:0] px, py,         // input pixel counters  
  output logic [9:0] hx, hy,        // ouput hdmi counters
  output logic [23:0] rgb_h,        // rgb to hdmi
  output logic stall                // stall input pipeline to sync with hdmi frame
);

    localparam int EXCESS_CYCLES_TWOFRAMES = (OFRAME_HEIGHT - IFRAME_HEIGHT*SUB_Y)*IFRAME_WIDTH;
    localparam int EXCESS_CYCLES_EVEN = EXCESS_CYCLES_TWOFRAMES >> 1;
    localparam int EXCESS_CYCLES_ODD = EXCESS_CYCLES_EVEN + EXCESS_CYCLES_TWOFRAMES[0];

    // assert(OFRAME_HEIGHT >= IFRAME_HEIGHT*SUB_Y);

    logic [23:0] ibuf [0:ISCREEN_WIDTH-1];     // input buffer from ppu
    logic [23:0] obuf [0:ISCREEN_WIDTH-1];     // playback buffer to hdmi

// clk_p domain (slower)
//

    // buffer incoming pixels in buff1
    // stall input pipeline as needed to maintain sync with hdmi
    int i;

    logic [8:0] stall_cnt;
    assign stall = ~(stall_cnt == 0);

    // signal we have buffered the first line, and hdmi frame can start
    wire first_line_done = py==0 && px==ISCREEN_WIDTH;

    // ppu and hdmi counters may vary slightly eveey other frame due to odd cycle
    // so only force sync every other frame
    wire signal_new_frame = first_line_done && ~frame_odd; 

    // starting the last line which will initialize stalls if needed
    wire last_line_start = py==IFRAME_HEIGHT-1 && px==0;

    // parity bit to track even/odd frames
    logic frame_odd;
    always_ff @(posedge clk_p) begin
        if (rst_p) begin
            for (i = 0; i < ISCREEN_WIDTH; i++) ibuf[i] <= 24'hff0000;
            stall_cnt <= 0;
            frame_odd <= 0;
        end else begin
            for (i = 0; i < ISCREEN_WIDTH; i++) ibuf[i] <= ibuf[i];
            if (px < ISCREEN_WIDTH) ibuf[px] <= rgb_p;

            stall_cnt <= stall ? stall_cnt-1 : 0;
            frame_odd <= frame_odd;

            // initiate stall on final scan line
            if (last_line_start) begin
                stall_cnt <= frame_odd ? EXCESS_CYCLES_ODD : EXCESS_CYCLES_EVEN;
                frame_odd <= ~frame_odd;
            end
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

    logic new_frame, new_frame_r, new_frame_rr;
    wire new_hline = hx == OFRAME_WIDTH - 1;
    wire new_hframe = new_frame_rr || (hy == OFRAME_HEIGHT - 1 && new_hline);
    
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

            new_frame <= 0;
            new_frame_r <= 0;
            new_frame_rr <= 0;
        end
        else
        begin

            new_frame <= aux[0] && signal_new_frame;
            new_frame_r <= new_frame;
            new_frame_rr <= new_frame_r;

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

    wire [23:0] rgb_buf = aux[0] ? 24'h00ff00 : obuf[hx_idx];


endmodule
