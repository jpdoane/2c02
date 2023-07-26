
module oam #(
        parameter OAM_INIT={`ROM_PATH,"oam.mem"}
    )(
    input logic clk, rst, rend,
    input logic [8:0] cycle,
    input logic [8:0] scan,
    input logic [7:0] oam_addr_i,
    input logic oam_addr_wr,
    input logic [7:0] oam_din,
    input logic oam_wr,
    input logic [7:0] ppuctrl,
    output logic [7:0] oam_dout,
    output logic [12:0] pattern_idx,
    output logic [7:0] attribute,
    output logic overflow, sp0,                  // OAM2[0] is sprite 0
    output logic [7:0] x 
    );

    initial $display("%s", OAM_INIT);
    logic [7:0] OAM  [255:0];
    logic [7:0] OAM2 [31:0];             //secondary OAM

    logic [7:0] oam_addr;
    logic [4:0] oam2_addr;
    logic[7:0] oam2_dout;
    logic[7:0] oam2_din;
    logic oam2_wr;

    wire [5:0] n = oam_addr[7:2];
    wire [1:0] m = oam_addr[1:0];
    wire [2:0] n2 = oam2_addr[4:2];
    wire [1:0] m2 = oam2_addr[1:0];

    logic [1:0] state, next_state;
    logic [8:0] scan_r;

    logic new_scan;
    logic oam2_rst;
    logic oam2_inc;
    logic oam_rst;
    logic oam_inc;
    logic oam_next;
    logic cpy_oam2;
    logic clr_oam2;
    logic full, set_of, set_full;
    logic set_sp0_hit, sp0_hit;
    logic save_y, save_nt, save_at, save_x;

    logic cyc_even;
    assign cyc_even = ~cycle[0];

    logic [7:0] y, nt;
    wire flip_y = attribute[7];

    logic ysrc;
    //y index into sprite pattern
    wire [8:0] sp_yi = scan_r - (ysrc ? oam_dout : y);    // on copy use y coord from oam, otherwise use registered y coord
    wire sp_inscan = ~(ppuctrl[PPUCTRL_H] ? |sp_yi[8:4] : |sp_yi[8:3]); //is this sprite in the current scan line?

    // flip sprite y pattern index if needed
    wire [3:0] sp_yiflip = ~flip_y ? sp_yi[3:0] : 
                            ppuctrl[PPUCTRL_H] ? 4'hf - sp_yi[3:0] : 4'h7 - sp_yi[3:0];

    logic pat_bitsel;
    assign pat_bitsel = cycle[1]; //fetch pattern bit 0 on cycle 4 (mod8), and pattern bit 1 on cycle 6 (mod8)
    assign pattern_idx = ppuctrl[PPUCTRL_H] ? {nt[0], nt[7:1], sp_yiflip[3], pat_bitsel, sp_yiflip[2:0]} //16 px sprites
                                            : {ppuctrl[PPUCTRL_S], nt, pat_bitsel, sp_yiflip[2:0]};   //8px sprites


    always @(posedge clk) begin
        if (rst) begin
            state <= OAM_IDLE;
            oam_addr <= 0;
            oam2_addr <= 0;
            full <= 0;
            overflow <= 0;
            sp0 <= 0;
            sp0_hit <= 0;
            y <= 8'd240;
            nt <= 0;
            attribute <= 0;
            x <= 0;
            scan_r <= 0;
        end else begin

            scan_r <= new_scan ? scan : scan_r;
            state <= next_state;

            oam_addr <= oam_rst ? 0:
                        oam_addr_wr ? oam_addr_i:
                        oam_next ? oam_addr + 4 :     // n++, m=0
                        oam_inc ? oam_addr + 1 :        // m++
                        oam_addr;

            oam2_addr <=oam2_rst ? 0:
                        oam2_inc ? oam2_addr + 1 :
                        oam2_addr;

            full <= new_scan ? 0 : full || set_full;
            overflow <= new_scan ? 0 : overflow || set_of;
            sp0_hit <= new_scan ? 0 : set_sp0_hit | sp0_hit;
            sp0 <= new_scan ? sp0_hit : sp0;

            y <= save_y ? oam2_dout : y;
            nt <= save_nt ? oam2_dout : nt;
            attribute <= save_at ? oam2_dout : attribute;
            x <= save_x ? oam2_dout : x;

        end
    end

    wire [2:0] cycle8 = cycle[2:0];
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
        save_y = 0;
        save_nt= 0;
        save_at= 0;
        save_x = 0;
        set_sp0_hit = 0;

        ysrc = 0;

        next_state = state;
        new_scan = 0;

        if (rend) begin
            case(cycle)
                9'd0:       begin
                            oam2_rst = 1;
                            new_scan = 1;
                            next_state = OAM_CLEAR;
                            end
                9'd64:         begin
                            oam2_rst = 1;
                            next_state = OAM_UPDATE;
                            end
                9'd256:        begin
                            oam2_rst = 1;
                            next_state = OAM_FETCH;
                            end
                default:    next_state = state;
            endcase
        end else begin
            next_state = OAM_IDLE;
        end


        case(state)
            OAM_CLEAR: begin
                // clear next oam2 address every even cycle
                clr_oam2 = 1;
                oam2_inc = cyc_even;
            end
            OAM_UPDATE: begin
                cpy_oam2 = 1;
                ysrc = 1; // get y coord from oam, not oam2
                // copy valid sprites from oam->oam2
                if (cyc_even) begin
                    if (m2==0 && ~sp_inscan) begin                        
                        // y coord fetch, check if sprite is on this scanline
                        //if not, skip oam to next and hold oam2
                        oam_next = 1;
                        oam2_inc = 0;

                    end else begin
                        //mark a hit on sprite 0
                        set_sp0_hit = oam_addr==0;

                        // sprite is in range, advance pointers for copy
                        oam_inc = 1;
                        oam2_inc = 1;

                        // if we we already full, this is an overflow
                        set_of = full;

                        // check if we've filled up oam2
                        // this will disable further writes
                        set_full = &oam2_addr;
                    end
                    if (&n && (oam_next || (oam_inc && &m))) next_state = OAM_IDLE;
                end
            end
            OAM_FETCH: begin
                oam_rst = 1;            // keep oam_addr = 0
                oam2_inc = 1;           // walk through oam2, unless cancelled below
                case(cycle8)
                    3'h0:  begin end //fetch y
                    3'h1:  save_y = 1;
                    3'h2:  save_nt = 1;
                    3'h3:  save_at = 1;
                    3'h4:  begin save_x = 1; oam2_inc=0; end
                    default: oam2_inc=0; // hold oam2 on other cycles
                endcase
            end
            default: begin oam2_inc = 1; end //IDLE
        endcase
    end

    // OAM memory
    always @(posedge clk) begin
        if (oam_wr) OAM[oam_addr] <= oam_din;
    end
    assign oam_dout = OAM[oam_addr];

    // OAM2 memory
    assign oam2_din = clr_oam2 ? 8'hff : oam_dout;
    assign oam2_wr = (cpy_oam2 || clr_oam2) && cyc_even && ~full;
    always @(posedge clk) begin
        if (oam2_wr) OAM2[oam2_addr] <= oam2_din;
    end
    assign oam2_dout = OAM2[oam2_addr];
    
    integer file, cnt;
    initial begin
        if (OAM_INIT != "") begin
            $display("Loading OAM memory: %s ", OAM_INIT);
            $readmemh(OAM_INIT, OAM);
        end
    end

endmodule
