parameter CHR_DEPTH 13;
parameter VRAM_DEPTH 12;
parameter PAL_DEPTH 5;
parameter ADDR_DEPTH 15;

parameter SPRITE_DEPTH 6;

module sprites(
    input logic clk, rst, ena,
    input logic [14:0] addr,
    input logic load_sprites,
    input logic rw,
    input logic tall,
    input logic [7:0] data_i,
    output logic [7:0] data_o
    );

    logic [7:0] OAM  [SPRITE_DEPTH-1:0][3:0];
    logic [7:0] OAM2 [4:0][3:0];             //secondary OAM

    logic sp_overflow, sp_valid;
    logic [SPRITE_DEPTH-1:0] n;
    logic [4:0] n2;
    logic [3:0] m;
    logic state, next_state;    
    logic [7:0] oam_rd;

    logic inc_m, inc_n, inc_n2;
    logic m0, m3;
    logic oam_done;
    assign m0 = ~|m;
    assign m3 = &m;
    assign inc_n = inc_m && m3;
    assign inc_n2 = inc_n && sp_valid;
    assign oam_done = inc_n && &n;

    always @(posedge clk ) begin
        if (rst) begin
            n <= 0;
            n2 <= 0;
            m <= 0;
            sp_valid <= 0;
            sp_overflow <= 0;
            state <= OAM_IDLE;
        end else begin
            if (load_sprites) begin
                n <= 0;
                n2 <= 0;
                m <= 0;
                sp_valid <= 0;
                sp_overflow <= 0;
                state <= OAM_RD;
            end else begin
                // mark sprite as valid if sp_miss==0 on m==0 phase.  clear on next n2 
                sp_valid <= (m0 && ~sp_miss) ? 1 : inc_n2 ? 0 : sp_valid;  //on m=0 (y coord), register validity of this sprite
                m <= inc_m ? m+1 : m;
                n <= inc_n ? n + 1 : n;
                n2 <= inc_n2 ? n2 + 1 : n2;
                sp_overflow <= (inc_n2 && &n2) ? 1 : sp_overflow // mark overflow of n2
                state <= oam_done ? OAM_IDLE : next_state;
            end
        end
    end 


    logic [7:0] line_plus;
    logic sp_miss, sp_hit;
    assign line_plus = tall ? scan_line + 16 : scan_line + 8;
    assign sp_miss = (scan_line < oam_rd) || (line_plus >= oam_rd);

    // OAM copy state machine
    always @(*) begin
        inc_m = 0;
        case(state)
            OAM_RD:     begin
                        next_state = OAM2_CP;       //fetch OAM[n][m]
                        end
            OAM2_CP:    begin
                        cpy_oam = sp_valid && !sp_overflow; // copy OAM2[n2][m] <= OAM[n][m]
                        inc_m = 1;
                        next_state = OAM_RD;
            OAM_IDLE:   next_state = OAM_IDLE;
            default:    next_state = OAM_IDLE;
        endcase
    end

    always @(posedge clk) begin
        oam_rd <= OAM[n][m];
    end

    logic cpy_oam;
    always @(posedge clk) begin
        OAM2[i] <= 8'hff;
        if (cpy_oam)  OAM2[n2][m] <= oam_rd;
    end

endmodule
