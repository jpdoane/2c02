`timescale 1ns/1ps

module cpu_sim
    #(
        parameter START_X = 0,
        parameter START_Y = 0,
        parameter AUTOSCROLL_FRAMES = 0
    )(
    input logic clk, rst,
    input logic nmi,
    input logic left,
    input logic right,
    output logic rw,
    output logic [15:0] addr,
    output logic [7:0] data_o,
    input logic [7:0] data_i

    );
    localparam PPU_CTRLWORD = 8'h90; // enanble NMI and select upper NT

    localparam WRITE_CTRL=3'h0;
    localparam CLEAR_DATA=3'h1;
    localparam READ_CTRL=3'h2;
    localparam WRITE_SCROLLX=3'h3;
    localparam WRITE_SCROLLY=3'h4;
    localparam IDLE=3'h5;


    logic [7:0] xscroll, yscroll;
    logic [7:0] frame_cnt;

    logic nmi_r;
    wire nmi_re = nmi && ~nmi_r;

    logic left_r, right_r;
    wire left_re = left && ~left_r;
    wire right_re = right && ~right_r;

    logic [2:0] state, next_state;

    always_ff @(posedge clk) begin
        if(rst) begin
            nmi_r <= 0;
            xscroll <= START_X;
            yscroll <= START_Y;
            frame_cnt <= 0;
            left_r <= 0;
            right_r <= 0;
            state <= WRITE_CTRL;
        end else begin

            nmi_r <= nmi;
            left_r <= left;
            right_r <= right;

            state <= next_state;

            xscroll <= left_re ? xscroll - 1 :
                         right_re ? xscroll + 1 :
                         xscroll;

            yscroll <= yscroll;

            frame_cnt <= frame_cnt;

            if (nmi_re) begin
                if (frame_cnt == AUTOSCROLL_FRAMES-1) begin
                    frame_cnt <= 0;
                    xscroll <= xscroll+1;
                end else begin
                    frame_cnt <= frame_cnt + 1;
                end
            end

        end
    end



    always_comb begin
        rw = 1;
        addr = 0;
        data_o = 0;
        next_state = WRITE_CTRL;
        case(state)
            WRITE_CTRL: begin
                            rw = 0;
                            addr = 16'h2000;
                            data_o = PPU_CTRLWORD;
                            next_state = READ_CTRL;
                        end
            // CLEAR_DATA: begin
            //                 // clear the data latch, to make sure we arent just reading back our own data...
            //                 rw = 0;
            //                 addr = 16'h2002;
            //                 data_o = 0;
            //                 next_state = READ_CTRL;
            //             end
            READ_CTRL: begin
                            rw = 1;
                            addr = 16'h2000;
                            next_state = (data_i == PPU_CTRLWORD) ? WRITE_SCROLLX : WRITE_CTRL;
                        end
            WRITE_SCROLLX: begin
                            rw = 0;
                            addr = 16'h2005;
                            data_o = xscroll;
                            next_state = WRITE_SCROLLY;
                        end
            WRITE_SCROLLY: begin
                            rw = 0;
                            addr = 16'h2005;
                            data_o = yscroll;
                            next_state = IDLE;
                        end
            IDLE:       begin
                            rw = 1;
                            next_state = nmi_re ? WRITE_CTRL : IDLE;
                        end
        endcase
    end


endmodule