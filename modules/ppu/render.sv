
module render #( parameter EXTERNAL_FRAME_TRIGGER=0 )
    (
    input logic clk, rst,
    input logic new_frame,
    // output logic [2:0] sp_id,
    // output logic [2:0] sp_attr,
    // input logic [7:0] sp_data,
    input logic [2:0] fine_x,
    input logic [7:0] ppuctrl,

    input logic [7:0] data_i,
    input logic [1:0] attr_i,
    output logic fetch_attr, fetch_chr,
    output logic [12:0] pattern_idx,
    output logic [4:0] palette_idx,

    output logic px_en, rend, vblank, inc_cx, inc_y, sp0, sp_of,
    output logic return00
    );


    logic [8:0] y, cycle;
    logic [2:0] fine_y;
    logic [7:0] nt, at, pat0, pat1;
    logic [1:0] pal;
    assign fine_y = y[2:0];

    // tile fetch loop
    logic load_sr, prerender, postrender, vis_line;
    assign rend = ~(vblank || postrender);
    assign vis_line = rend & ~prerender;

    logic fetch_nt, fetch_pat0, fetch_pat1;
    logic save_nt, save_attr, save_pat0, save_pat1;
    assign fetch_chr = fetch_pat0 | fetch_pat1;

    logic sp_eval, load_sp_sr;
    logic sp0_line, sp0_opaque;

    logic [7:0] oam_addr_i;
    logic oam_addr_wr;
    logic [7:0] oam_din;
    logic oam_wr;
    logic [7:0] oam_dout;
    logic [12:0] sp_pattern_idx;
    logic [1:0] sp_palette_idx;
    logic [7:0] sp_attribute;
    logic [7:0] sp_x;
    
    assign oam_addr_i=0;
    assign oam_addr_wr=0;
    assign oam_din=0;
    assign oam_wr=0;
            
    // wrap to -1 for prerender line unless EXTERNAL_FRAME_TRIGGER, in which case y wraps to -1 (prerend) on external trigger
    wire [8:0] ynext;
    wire trigger_frame;
    generate 
        if (EXTERNAL_FRAME_TRIGGER) begin
            assign ynext = y+1;
            assign trigger_frame = new_frame;
        end else begin
            assign ynext = (y==FRAME_HEIGHT-2) ? 9'h1ff : y+1;
            assign trigger_frame = 0;
        end
    endgenerate


    always @(posedge clk) begin
        if (rst) begin
            // fetch_attr <= 0;
            // fetch_chr <= 0;
            nt <= 0;
            pal <= 0;
            pat0 <= 0;
            pat1 <= 0;
            px_en <= 0;
            vblank <= 0;
            y <= -1; //prerender
            cycle <= 0;
            return00 <= 0;
            postrender <= 0;
            prerender <= 1;
            sp_eval <= 0;

            inc_y <= 0;
            load_sp_sr <= 0;
            sp0 <= 0;
            sr_en <= 0;
        end
        else begin

            nt <=   save_nt ? data_i : nt;
            pal <=  save_attr ? attr_i : pal;
            pat0 <= save_pat0 ? data_i : pat0;
            pat1 <= save_pat1 ? data_i : pat1;

            prerender<=0;
            postrender<=0; 
            vblank <= vblank;
            sp_eval <= sp_eval;
            sr_en<=sr_en;
            px_en <= px_en;
            y <= y;
            cycle <= cycle + 1; 

            sp0 <= (sp0_opaque && bg_opaque) || sp0;
            inc_y <= 0;
            load_sp_sr <= 0;
            return00 <= prerender && return00;

            if (trigger_frame) begin
                y <= 9'h1ff; //prerender
                cycle <= 0;
                sp_eval <= 0;
                px_en <= 0;
                sr_en <= 1;
                return00 <= 0;
            end else begin

                // update screen state
                // these flags take effect on cycle 1 (after first cycle of new y)
                case(y)
                    9'h1ff:                 begin //prerender
                                        vblank <= 0;
                                        prerender <= 1;
                                        sp0 <= 0;
                                        end
                    SCREEN_HEIGHT:      postrender <= 1;
                    SCREEN_HEIGHT+1:    vblank <= 1;
                endcase

                case(cycle)
                    0:              begin sr_en <=1; px_en <= vis_line; end
                    SCREEN_WIDTH:   begin px_en <= 0; inc_y <= 1; sp_eval <= rend; end
                    CYCLE_RESETON:  begin return00 <= prerender; end
                    CYCLE_RESETOFF: return00 <= 0;
                    CYCLE_SPDONE:   begin sp_eval <= 0; load_sp_sr <= vis_line; y<=ynext; end
                    CYCLE_BADFETCH: sr_en <= 0;
                    CYCLE_LAST:     begin sr_en <=1; cycle <= 0; end
                endcase
            end    
        end
    end

    wire [2:0] cycle8 = cycle[2:0];
    always_comb begin
        load_sr = 0;
        fetch_nt = 0;
        save_nt = 0;
        fetch_attr = 0;
        save_attr = 0;
        fetch_pat0 = 0;
        save_pat0 = 0;
        fetch_pat1 = 0;
        save_pat1 = 0;
        inc_cx = 0;
        if (rend) begin
            case(cycle8)
                3'h0:   begin load_sr =1; fetch_nt=1; end
                3'h1:   save_nt = 1;
                3'h2:   fetch_attr = 1;
                3'h3:   save_attr = 1;
                3'h4:   fetch_pat0 = 1;
                3'h5:   save_pat0 = 1;
                3'h6:   fetch_pat1 = 1;
                3'h7:   begin save_pat1 = 1; inc_cx = ~sp_eval; end
            endcase
        end
    end

    // decode index into pattern table
    logic pat_bitsel;
    assign pat_bitsel = cycle[1]; //fetch pattern bit 0 on cycle 4 (mod8), and pattern bit 1 on cycle 6 (mod8)
    assign pattern_idx = sp_eval ? sp_pattern_idx : {ppuctrl[PPUCTRL_B], nt, pat_bitsel, fine_y};

    // assign pattern_idx = pattern_sp | pattern_bg;

    // background shift registers
    logic [2:0]  pal_dat;          //palette
    logic [7:0]  pal_sr1, pal_sr0;          //palette
    logic [15:0] tile_sr1, tile_sr0;        //tile data
    logic sr_en;        //enable shifting
    always @(posedge clk) begin
        if (rst) begin
            tile_sr0 <= 0;
            tile_sr1 <= 0;
            pal_sr0 <= 0;
            pal_sr1 <= 0;
            pal_dat <= 0;
        end else begin
            if (sr_en) begin
                tile_sr0 <=  {tile_sr0[14:0], 1'b0};
                tile_sr1 <=  {tile_sr1[14:0], 1'b0};
                pal_sr0 <=  {pal_sr0[6:0], pal_dat[0]};
                pal_sr1 <=  {pal_sr1[6:0], pal_dat[1]};
                if (load_sr) begin
                    // shift in new tile
                    tile_sr0[7:0] <= pat0;
                    tile_sr1[7:0] <= pat1;
                    pal_dat <= pal;
                end
            end else begin
                tile_sr0 <= tile_sr0;
                tile_sr1 <= tile_sr1;
                pal_sr0 <=  pal_sr0;
                pal_sr1 <=  pal_sr1;
            end
        end
    end

    // fine_x=0 selects MSB, 7 selects LSB, so flip bit order for SR output
    wire [0:7] tile_sr0_flip = tile_sr0[15:8];
    wire [0:7] tile_sr1_flip = tile_sr1[15:8];
    wire [0:7] pal_sr0_flip = pal_sr0[7:0];
    wire [0:7] pal_sr1_flip = pal_sr1[7:0];
    wire [1:0] bg_px = {tile_sr1_flip[fine_x], tile_sr0_flip[fine_x]};
    wire [1:0] bg_pal = {pal_sr1_flip[fine_x], pal_sr0_flip[fine_x]};

    // sprite object memory
    oam u_oam(
        .clk         (clk         ),
        .rst         (rst         ),
        .rend        (vis_line        ),
        .cycle       (cycle        ),
        .scan        (ynext),
        .oam_addr_i  (oam_addr_i  ),
        .oam_addr_wr (oam_addr_wr ),
        .oam_din     (oam_din     ),
        .oam_wr      (oam_wr      ),
        .ppuctrl     (ppuctrl     ),
        .oam_dout    (oam_dout    ),
        .pattern_idx (sp_pattern_idx ),
        .attribute   (sp_attribute   ),
        .overflow    (sp_of    ),
        .sp0         (sp0_line     ),
        .x           (sp_x           )
    );

    // sprite rendering
    generate
        for (genvar i=0;i<8;i=i+1) begin : sp
            logic [3:0] px;
            logic pri;
            sprite #(.index (i) ) u_sprite(
                .clk       (clk       ),
                .rst       (rst       ),
                .cycle     (cycle     ),
                .eval      (sp_eval   ),
                .px_en      (px_en),
                .save_pat0 (save_pat0 ),
                .save_pat1 (save_pat1 ),
                .load_sr   (load_sp_sr  ),
                .at_i      (sp_attribute ),
                .pat_i     (data_i      ),
                .x_i       (sp_x        ),
                .px        (px   ),
                .pri       (pri  )
            );
        end
    endgenerate

    // final sprite mux (highest priority non transparent sprite)
    logic sp_pri;
    logic [3:0] sp_px;
    always @(*) begin
        sp_px = 4'h0;
        sp_pri = 1;
        sp0_opaque = 0;
        if (|sp[7].px[1:0]) begin sp_px = sp[7].px; sp_pri = sp[7].pri; end
        if (|sp[6].px[1:0]) begin sp_px = sp[6].px; sp_pri = sp[6].pri; end
        if (|sp[5].px[1:0]) begin sp_px = sp[5].px; sp_pri = sp[5].pri; end
        if (|sp[4].px[1:0]) begin sp_px = sp[4].px; sp_pri = sp[4].pri; end
        if (|sp[3].px[1:0]) begin sp_px = sp[3].px; sp_pri = sp[3].pri; end
        if (|sp[2].px[1:0]) begin sp_px = sp[2].px; sp_pri = sp[2].pri; end
        if (|sp[1].px[1:0]) begin sp_px = sp[1].px; sp_pri = sp[1].pri; end
        if (|sp[0].px[1:0]) begin sp_px = sp[0].px; sp_pri = sp[0].pri; sp0_opaque = sp0_line; end
    end

    // final pixel mux
    // draw sprite if it has priority or bg is transparent
    // else draw opaque bg, or zero for transparent bg
    wire bg_opaque = |bg_px;
    wire sp_opaque = |sp_px[1:0];
    wire draw_sprite = sp_opaque && (~sp_pri || bg_opaque);
    assign palette_idx = draw_sprite ? {1'b1, sp_px} : {1'b0, bg_pal & {2{bg_opaque}}, bg_px};   

    // final pixel color: PAL[palette_idx] (done elsewhere)

endmodule