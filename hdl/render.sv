
module render
    (
    input logic clk, rst,

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

    output logic px_en, rend, vblank, inc_cx, inc_y,
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


    logic [7:0] oam_addr_i;
    logic oam_addr_wr;
    logic [7:0] oam_din;
    logic oam_wr;
    logic [7:0] oam_dout;
    logic [12:0] sp_pattern_idx;
    logic [1:0] sp_palette_idx;
    logic [7:0] sp_attribute;
    logic sp0;
    logic [7:0] sp_x;
    
    assign oam_addr_i=0;
    assign oam_addr_wr=0;
    assign oam_din=0;
    assign oam_wr=0;




    wire [8:0] ynext = prerender ? 0 : y+1;
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
            y <= Y_PRERENDER;
            cycle <= 0;
            load_sr<=0;
            return00 <= 0;
            postrender <= 0;
            prerender <= 1;
            sp_eval <= 0;

            inc_cx <= 0;
            inc_y <= 0;
            load_sp_sr <= 0;

        end
        else begin

            nt <=   save_nt ? data_i : nt;
            pal <=  save_attr ? attr_i : pal;
            pat0 <= save_pat0 ? data_i : pat0;
            pat1 <= save_pat1 ? data_i : pat1;

            sp_eval <= sp_eval;

            vblank <= vblank;
            postrender <= postrender;
            prerender <= prerender;
            return00 <= 0;

            px_en <= px_en;
            y <= y;
            cycle <= cycle + 1; 

            inc_cx <= 0;
            inc_y <= 0;
            load_sp_sr <= 0;
            return00 <= prerender && return00;
            case(cycle)
                0:              begin sr_en <=1; px_en <= vis_line; end
                SCREEN_WIDTH:   begin px_en <= 0; inc_y <= 1; y<=ynext; sp_eval <= rend; end
                CYCLE_RESETON:  begin return00 <= prerender; end
                CYCLE_RESETOFF: return00 <= 0;
                CYCLE_SPDONE:   begin sp_eval <= 0; load_sp_sr <= vis_line; end
                CYCLE_BADFETCH: sr_en <= 0;
                CYCLE_LAST:     begin sr_en <=1; cycle <= 0; prerender<=0; postrender<=0; end
            endcase
            
            // these flags take effect on cycle 1 (after first cycle of new y)
            case(y)
                Y_PRERENDER:    begin
                                vblank <= 0;
                                prerender <= 1;
                                end
                Y_POSTRENDER:   postrender <= 1;
                Y_BLANK:        vblank <= 1;
            endcase

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
                tile_sr0 <=  {tile_sr0[14:0], 1'bx}; //shift in X's to aid debuging
                tile_sr1 <=  {tile_sr1[14:0], 1'bx}; //shift in X's to aid debuging
                pal_sr0 <=  {pal_sr0[6:0], pal_dat[0]}; //shift in X's to aid debuging
                pal_sr1 <=  {pal_sr1[6:0], pal_dat[1]}; //shift in X's to aid debuging
                if (load_sr) begin
                    // shift in new tile
                    tile_sr0[7:0] <= pat0;
                    tile_sr1[7:0] <= pat1;
                    pal_dat <= pal;
                end
                // if (sp_eval) begin
                //     // helpful for debugging
                //     tile_sr0[7:0] <= 'x;
                //     tile_sr1[7:0] <= 'x;
                //     pal_dat <= 'x;
                // end
            end else begin
                tile_sr0 <= tile_sr0;
                tile_sr1 <= tile_sr1;
                pal_sr0 <=  pal_sr0;
                pal_sr1 <=  pal_sr1;
            end
        end
    end

    // select bg pixel and palette
    logic [1:0] bg_px, bg_pal;
    logic [7:0] tile_sr0_out, tile_sr1_out;
    assign tile_sr0_out = tile_sr0[15:8];
    assign tile_sr1_out = tile_sr1[15:8];
    always_comb begin
        bg_px = {tile_sr1_out[fine_x], tile_sr0_out[fine_x]};
        bg_pal = {pal_sr1[fine_x], pal_sr0[fine_x]};
    end

    logic sp_pri;
    logic [1:0] sp_px, sp_pal;

    // index into palette table:
    // 43210
    // |||||
    // |||++- Pixel value from tile data
    // |++--- Palette number from attribute table or OAM
    // +----- Background/Sprite select
    logic bg_trans;
    assign bg_trans = ~|bg_px;
    wire draw_sprite = |sp_px && (~sp_pri || bg_trans);
    assign palette_idx = draw_sprite ? {1'b1, sp_pal, sp_px} : // draw sprite if it has priority or bg is transparent
                            {1'b0, bg_pal & {2{~bg_trans}}, bg_px};   // else draw background (zero if bg is also transparent)


    //sprite data registers
    logic [7:0] sp0_pat0, sp1_pat0, sp2_pat0, sp3_pat0, sp4_pat0, sp5_pat0, sp6_pat0, sp7_pat0;
    logic [7:0] sp0_pat1, sp1_pat1, sp2_pat1, sp3_pat1, sp4_pat1, sp5_pat1, sp6_pat1, sp7_pat1;
    logic [7:0] sp0_at, sp1_at, sp2_at, sp3_at, sp4_at, sp5_at, sp6_at, sp7_at;
    logic [7:0] sp0_x, sp1_x, sp2_x, sp3_x, sp4_x, sp5_x, sp6_x, sp7_x;
    wire sp_flip_x = sp_attribute[6];
    wire [7:0] data_i_rev = {data_i[0],data_i[1],data_i[2],data_i[3],data_i[4],data_i[5],data_i[6],data_i[7]};

    // save sprite data
    always @(posedge clk) begin
        if (rst) begin
            sp0_pat0 <= 0;
            sp0_pat1 <= 0;
            sp1_pat0 <= 0;
            sp1_pat1 <= 0;
            sp2_pat0 <= 0;
            sp2_pat1 <= 0;
            sp3_pat0 <= 0;
            sp3_pat1 <= 0;
            sp4_pat0 <= 0;
            sp4_pat1 <= 0;
            sp5_pat0 <= 0;
            sp5_pat1 <= 0;
            sp6_pat0 <= 0;
            sp6_pat1 <= 0;
            sp7_pat0 <= 0;
            sp7_pat1 <= 0;
            sp0_at <= 0;
            sp1_at <= 0;
            sp2_at <= 0;
            sp3_at <= 0;
            sp4_at <= 0;
            sp5_at <= 0;
            sp6_at <= 0;
            sp7_at <= 0;
            sp0_x <= 0;
            sp1_x <= 0;
            sp2_x <= 0;
            sp3_x <= 0;
            sp4_x <= 0;
            sp5_x <= 0;
            sp6_x <= 0;
            sp7_x <= 0;            
        end else begin

            sp0_pat0 <= sp0_pat0;
            sp0_pat1 <= sp0_pat1;
            sp1_pat0 <= sp1_pat0;
            sp1_pat1 <= sp1_pat1;
            sp2_pat0 <= sp2_pat0;
            sp2_pat1 <= sp2_pat1;
            sp3_pat0 <= sp3_pat0;
            sp3_pat1 <= sp3_pat1;
            sp4_pat0 <= sp4_pat0;
            sp4_pat1 <= sp4_pat1;
            sp5_pat0 <= sp5_pat0;
            sp5_pat1 <= sp5_pat1;
            sp6_pat0 <= sp6_pat0;
            sp6_pat1 <= sp6_pat1;
            sp7_pat0 <= sp7_pat0;
            sp7_pat1 <= sp7_pat1;
            sp0_at <= sp0_at;
            sp1_at <= sp1_at;
            sp2_at <= sp2_at;
            sp3_at <= sp3_at;
            sp4_at <= sp4_at;
            sp5_at <= sp5_at;
            sp6_at <= sp6_at;
            sp7_at <= sp7_at;
            sp0_x <= sp0_x;
            sp1_x <= sp1_x;
            sp2_x <= sp2_x;
            sp3_x <= sp3_x;
            sp4_x <= sp4_x;
            sp5_x <= sp5_x;
            sp6_x <= sp6_x;
            sp7_x <= sp7_x;            

            if (sp_eval && save_pat0) begin
                //save sprite patten bit 0
                case (sp_idx)
                    3'h0:  sp0_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h1:  sp1_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h2:  sp2_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h3:  sp3_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h4:  sp4_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h5:  sp5_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h6:  sp6_pat0 <= sp_flip_x ? data_i_rev : data_i;
                    3'h7:  sp7_pat0 <= sp_flip_x ? data_i_rev : data_i;
                endcase
            end else if (sp_eval && save_pat1) begin
                //save sprite pattern bit 1, attribute, and x coord
                case (sp_idx)
                    3'h0:  begin
                        sp0_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp0_at <= sp_attribute;
                        sp0_x <= sp_x;
                        end
                    3'h1:  begin
                        sp1_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp1_at <= sp_attribute;
                        sp1_x <= sp_x;
                        end
                    3'h2:  begin
                        sp2_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp2_at <= sp_attribute;
                        sp2_x <= sp_x;
                        end
                    3'h3:  begin
                        sp3_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp3_at <= sp_attribute;
                        sp3_x <= sp_x;
                        end
                    3'h4:  begin
                        sp4_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp4_at <= sp_attribute;
                        sp4_x <= sp_x;
                        end
                    3'h5:  begin
                        sp5_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp5_at <= sp_attribute;
                        sp5_x <= sp_x;
                        end
                    3'h6:  begin
                        sp6_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp6_at <= sp_attribute;
                        sp6_x <= sp_x;
                        end
                    3'h7:  begin
                        sp7_pat1 <= sp_flip_x ? data_i_rev : data_i;
                        sp7_at <= sp_attribute;
                        sp7_x <= sp_x;
                        end

                endcase
            end
        end
    end


    // sprite shift registers & counters
    wire [2:0] sp_idx = cycle[5:3];
    logic [7:0]  sp0_sr0, sp0_sr1;  //sp 0
    logic [7:0]  sp1_sr0, sp1_sr1;  //sp 1
    logic [7:0]  sp2_sr0, sp2_sr1;  //sp 2
    logic [7:0]  sp3_sr0, sp3_sr1;  //sp 3
    logic [7:0]  sp4_sr0, sp4_sr1;  //sp 4
    logic [7:0]  sp5_sr0, sp5_sr1;  //sp 5
    logic [7:0]  sp6_sr0, sp6_sr1;  //sp 6
    logic [7:0]  sp7_sr0, sp7_sr1;  //sp 7

    // sprite enable flags
    logic sp0_en, sp1_en, sp2_en, sp3_en, sp4_en, sp5_en, sp6_en, sp7_en;
    // x counters
    logic [7:0] sp0_xc, sp1_xc, sp2_xc, sp3_xc, sp4_xc, sp5_xc, sp6_xc, sp7_xc;

    always @(posedge clk) begin
        if (rst) begin
            sp0_sr0 <= 0;
            sp0_sr1 <= 0;
            sp1_sr0 <= 0;
            sp1_sr1 <= 0;
            sp2_sr0 <= 0;
            sp2_sr1 <= 0;
            sp3_sr0 <= 0;
            sp3_sr1 <= 0;
            sp4_sr0 <= 0;
            sp4_sr1 <= 0;
            sp5_sr0 <= 0;
            sp5_sr1 <= 0;
            sp6_sr0 <= 0;
            sp6_sr1 <= 0;
            sp7_sr0 <= 0;
            sp7_sr1 <= 0;
            sp0_xc <= 0;
            sp1_xc <= 0;
            sp2_xc <= 0;
            sp3_xc <= 0;
            sp4_xc <= 0;
            sp5_xc <= 0;
            sp6_xc <= 0;
            sp7_xc <= 0;
        end else begin
            if (load_sp_sr) begin
                sp0_sr0 <= sp0_pat0;
                sp0_sr1 <= sp0_pat1;
                sp1_sr0 <= sp1_pat0;
                sp1_sr1 <= sp1_pat1;
                sp2_sr0 <= sp2_pat0;
                sp2_sr1 <= sp2_pat1;
                sp3_sr0 <= sp3_pat0;
                sp3_sr1 <= sp3_pat1;
                sp4_sr0 <= sp4_pat0;
                sp4_sr1 <= sp4_pat1;
                sp5_sr0 <= sp5_pat0;
                sp5_sr1 <= sp5_pat1;
                sp6_sr0 <= sp6_pat0;
                sp6_sr1 <= sp6_pat1;
                sp7_sr0 <= sp7_pat0;
                sp7_sr1 <= sp7_pat1;
            end else begin

                // initialize and decrement counters 
                sp0_xc <= ~px_en ? sp0_x : sp0_en ? sp0_xc : sp0_xc - 1;
                sp1_xc <= ~px_en ? sp1_x : sp1_en ? sp1_xc : sp1_xc - 1;
                sp2_xc <= ~px_en ? sp2_x : sp2_en ? sp2_xc : sp2_xc - 1;
                sp3_xc <= ~px_en ? sp3_x : sp3_en ? sp3_xc : sp3_xc - 1;
                sp4_xc <= ~px_en ? sp4_x : sp4_en ? sp4_xc : sp4_xc - 1;
                sp5_xc <= ~px_en ? sp5_x : sp5_en ? sp5_xc : sp5_xc - 1;
                sp6_xc <= ~px_en ? sp6_x : sp6_en ? sp6_xc : sp6_xc - 1;
                sp7_xc <= ~px_en ? sp7_x : sp7_en ? sp7_xc : sp7_xc - 1;        

                sp0_sr0 <= sp0_en ? sp0_sr0 << 1 : sp0_sr0;
                sp0_sr1 <= sp0_en ? sp0_sr1 << 1 : sp0_sr1;
                sp1_sr0 <= sp1_en ? sp1_sr0 << 1 : sp1_sr0;
                sp1_sr1 <= sp1_en ? sp1_sr1 << 1 : sp1_sr1;
                sp2_sr0 <= sp2_en ? sp2_sr0 << 1 : sp2_sr0;
                sp2_sr1 <= sp2_en ? sp2_sr1 << 1 : sp2_sr1;
                sp3_sr0 <= sp3_en ? sp3_sr0 << 1 : sp3_sr0;
                sp3_sr1 <= sp3_en ? sp3_sr1 << 1 : sp3_sr1;
                sp4_sr0 <= sp4_en ? sp4_sr0 << 1 : sp4_sr0;
                sp4_sr1 <= sp4_en ? sp4_sr1 << 1 : sp4_sr1;
                sp5_sr0 <= sp5_en ? sp5_sr0 << 1 : sp5_sr0;
                sp5_sr1 <= sp5_en ? sp5_sr1 << 1 : sp5_sr1;
                sp6_sr0 <= sp6_en ? sp6_sr0 << 1 : sp6_sr0;
                sp6_sr1 <= sp6_en ? sp6_sr1 << 1 : sp6_sr1;
                sp7_sr0 <= sp7_en ? sp7_sr0 << 1 : sp7_sr0;
                sp7_sr1 <= sp7_en ? sp7_sr1 << 1 : sp7_sr1;        
            end
        end
    end



    // sprite enable and pixel mux
    logic [1:0] sp0_px, sp1_px, sp2_px, sp3_px, sp4_px, sp5_px, sp6_px, sp7_px;
    logic sp7_pri, sp6_pri, sp5_pri, sp4_pri, sp3_pri, sp2_pri, sp1_pri, sp0_pri;
    always @(*) begin
        // sprites are enabled once their counter reaches 0

        sp0_en = px_en && sp0_xc==0;
        sp1_en = px_en && sp1_xc==0;
        sp2_en = px_en && sp2_xc==0;
        sp3_en = px_en && sp3_xc==0;
        sp4_en = px_en && sp4_xc==0;
        sp5_en = px_en && sp5_xc==0;
        sp6_en = px_en && sp6_xc==0;
        sp7_en = px_en && sp7_xc==0;


        // select pixel data for each sprite from shift register
        sp0_px = {sp0_sr1[7], sp0_sr0[7]};
        sp1_px = {sp1_sr1[7], sp1_sr0[7]};
        sp2_px = {sp2_sr1[7], sp2_sr0[7]};
        sp3_px = {sp3_sr1[7], sp3_sr0[7]};
        sp4_px = {sp4_sr1[7], sp4_sr0[7]};
        sp5_px = {sp5_sr1[7], sp5_sr0[7]};
        sp6_px = {sp6_sr1[7], sp6_sr0[7]};
        sp7_px = {sp7_sr1[7], sp7_sr0[7]};

        // final sprite pixel from highest priority non transparent sprite
        sp_px = 2'b00;
        sp_pri = 1;
        sp_pal = 2'b00;
        if (sp7_en & |sp7_px) begin sp_px = sp7_px; sp_pal = sp7_at[1:0]; sp_pri = sp7_at[5]; end
        if (sp6_en & |sp6_px) begin sp_px = sp6_px; sp_pal = sp6_at[1:0]; sp_pri = sp6_at[5]; end
        if (sp5_en & |sp5_px) begin sp_px = sp5_px; sp_pal = sp5_at[1:0]; sp_pri = sp5_at[5]; end
        if (sp4_en & |sp4_px) begin sp_px = sp4_px; sp_pal = sp4_at[1:0]; sp_pri = sp4_at[5]; end
        if (sp3_en & |sp3_px) begin sp_px = sp3_px; sp_pal = sp3_at[1:0]; sp_pri = sp3_at[5]; end
        if (sp2_en & |sp2_px) begin sp_px = sp2_px; sp_pal = sp2_at[1:0]; sp_pri = sp2_at[5]; end
        if (sp1_en & |sp1_px) begin sp_px = sp1_px; sp_pal = sp1_at[1:0]; sp_pri = sp1_at[5]; end
        if (sp0_en & |sp0_px) begin sp_px = sp0_px; sp_pal = sp0_at[1:0]; sp_pri = sp0_at[5]; end
    end


    sprites u_sprites(
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
        .attribute   (sp_attribute ),
        .sp0         (sp0         ),
        .x           (sp_x           )
    );



endmodule