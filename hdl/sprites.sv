
module sprites(
    input logic clk, rst, ena,
    input logic [14:0] addr,
    input logic load_sprites,
    input logic rw,
    input logic tall,
    input logic [7:0] data_i,
    output logic [7:0] data_o,

    output logic [12:0] pattern_idx,
    output logic [1:0] palette_idx,
    output logic pri, flip_x, flip_y, sp0,
    output logic [7:0] x
    );

    logic [7:0] OAM  [255:0];
    logic [7:0] OAM2 [31:0];             //secondary OAM

    logic [8:0] oam_addr;
    logic[7:0] oam_dout;
    logic[7:0] oam_din;
    logic oam_we;
    logic [4:0] oam2_addr;
    logic[7:0] oam2_dout;
    logic[7:0] oam2_din;
    logic oam2_we;


    logic [1:0] state, next_state;

    logic overflow, full, set_sp0;

    // set later
    assign oam_din = 8'h0;
    assign oam_we = 0;

    logic cyc_even;
    assign cyc_even = ~cycle[0];

    logic cpy_oam2, clr_oam2;

    logic [7:0] y, nt, at;
    assign palette_idx = at[1:0];
    assign pri = at[5];
    assign flip_x = at[6];
    assign flip_y = at[7];

    logic [7:0] sp_yi;      //y index into sprite pattern
    assign sp_yi = y[7:0] - oam_dat;
    logic sp_inscan;     //is this sprite in the current scan line?
    assign sp_inscan = ~(ppuctrl[PPUCTRL_H] ? |sp_yi[7:4] : |sp_yi[7:3]);

    logic pat_bitsel;
    assign pat_bitsel = cycle[1]; //fetch pattern bit 0 on cycle 4 (mod8), and pattern bit 1 on cycle 6 (mod8)
    assign pattern_idx = ppuctrl[PPUCTRL_H] ? {nt[0], nt[7:1], sp_yi[3], pat_bitsel, sp_yi[2:0]} //16 px sprites
                                            : {ppuctrl[PPUCTRL_S], nt, pat_bitsel, sp_yi[2:0]};   //8px sprites


    always_ff @(posedge clk) begin
        if (rst) begin

            y <= 0;
            nt <= 0;
            at <= 0;
            x <= 0;

            sp_valid <= 0;
        end else begin

            state <= next_state;

            oam_addr <= oam_next ? oam_addr + 4 :     // n++, m=0
                        oam_inc ? oam_addr + 1 :        // m++
                        oam_rst ? 0:
                        oam_addr;

            oam2_addr <= oam2_next ? oam2_addr + 4 :   //n++, m=0
                        oam2_inc ? oam2_addr + 1 :     //m++
                        oam2_rst ? 0:
                        oam2_addr;

            full <= clr_oam2 ? 0 : full || set_full;
            overflow <= clr_oam2 ? 0 : overflow || set_of;
            sp0_hit <= clr_oam2 ? 0 : set_sp0 | sp0_hit;

            y <= sp_rst ? 0 : save_y ? oam2_dat : y;
            nt <= sp_rst ? 0 : save_nt ? oam2_dat : nt;
            at <= sp_rst ? 0 : save_at ? oam2_dat : at;
            x <= sp_rst ? 0 : save_x ? oam2_dat : x;

        end
    end

    always_comb begin
        oam2_rst = 0;
        oam2_inc = 0;
        oam_rst = 0;
        oam_inc = 0;
        oam_next = 0;
        cpy_oam2=0;
        clr_oam2 = 0;

        set_of = 0;
        set_full = 0;
        clr_of = 0;
        clr_full = 0;
        save_y = 0;
        save_nt= 0;
        save_at= 0;
        save_x = 0;
        set_sp0 = 0;
        
        case(cycle)
            0:          begin
                        oam2_rst = 1;
                        clr_of = 1;
                        clr_full = 1;
                        next_state = CLR_OAM2;
                        end
            64:         begin
                        oam2_rst = 1;
                        next_state = UPDATE_OAM2;
                        end
            256:        next_state = SP_FETCH;
            default:    next_state = state;
        endcase


        case(state)
            CLR_OAM2: begin
                // clear next oam2 address every even cycle
                clr_oam2 = 1;
                oam2_inc = cyc_even;
            end
            UPDATE_OAM2: begin
                cpy_oam2 = 1;
                // copy valid sprites from oam->oam2
                if (cyc_even) begin
                    if (oam2_addr[0:2]==0 && ~sp_inscan) begin                        
                        // y coord fetch, check if sprite is on this scanline
                        //if not, skip oam to next and hold oam2
                        oam_next = 1;
                        oam2_inc = 0;
                    end else begin
                        //mark a hit on sprite 0
                        set_sp0 = oam_addr==0;

                        // sprite is in range, advance pointers for copy
                        oam_inc = 1;
                        oam2_inc = 1;

                        // if we we already full, this is an overflow
                        set_of = full;

                        // check if we've filled up oam2
                        // this will disable further writes
                        set_full = &oam2_addr;
                    end
                end
            end
            SP_FETCH: begin
                oam_rst = 1;            // keep oam_addr = 0
                oam2_inc = 1;           // walk through oam2, unless cancelled below
                sp0 = sp0_hit && (oam2_addr[4:2]==0); // if this is sprite 0, emit signal
                case(cycle[2:0])
                    1:  save_y = 1;
                    2:  save_nt = 1;
                    3:  save_at = 1;
                    4:  begin save_x = 1; oam2_inc=0; end
                    6:  begin oam2_inc=0; end
                    default: oam2_inc=0; // hold oam2 on other cycles
                endcase

                next_state = state;
            end
            default: begin end //IDLE
        endcase
    end


    // OAM memory
    always_ff @(posedge clk) begin
        if (oam_we) OAM[oam_addr] <= oam_din;
        oam_dout <= OAM[oam_addr];
    end

    // OAM2 memory
    assign oam2_din = clr_oam2 ? 8'hff : oam_dout;
    assign oam2_we = update_oam2 && cyc_even && ~full;
    always_ff @(posedge clk) begin
        if (oam2_we) OAM2[oam2_addr] <= oam2_din;
        oam2_dat <= OAM2[oam2_addr];
    end
    


endmodule
