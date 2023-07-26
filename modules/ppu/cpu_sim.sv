`timescale 1ns/1ps

module cpu_sim
    #( parameter SCROLLX_PER_FRAME = 3,
        parameter SCROLLY_PER_FRAME = 0
    )(
    input logic clk, rst,
    input logic nmi,
    output logic rw,
    output logic [15:0] addr,
    output logic [7:0] data_o,
    input logic [7:0] data_i

    );
    localparam PPU_CTRL = 8'h90; // enanble NMI ands select upper NT

    logic [7:0] xscroll, yscroll;
    logic nmi_r, ppu_ready;
    logic read_ppu_ctrl, write_ppu_ctrl, write_ppu_scroll1, write_ppu_scroll2;

    wire nmi_re = nmi && ~nmi_r;

    always_ff @(posedge clk) begin
        if(rst) begin
            read_ppu_ctrl <= 0;
            write_ppu_ctrl <= 0;
            write_ppu_scroll1 <= 0;
            write_ppu_scroll2 <= 0;
            nmi_r <= 0;
            xscroll <= 0;
            yscroll <= 0;
            ppu_ready <= 0;
        end else begin

            nmi_r <= nmi;

            // continually write to ppu ctrl until successful readback
            write_ppu_ctrl <= ~ppu_ready && ~write_ppu_ctrl;
            read_ppu_ctrl <= write_ppu_ctrl;
            ppu_ready <= ppu_ready || (read_ppu_ctrl && (data_i == PPU_CTRL));

            // update scroll position after every frame 
            xscroll <= nmi_re ? xscroll+SCROLLX_PER_FRAME : xscroll;
            yscroll <= nmi_re ? yscroll+SCROLLY_PER_FRAME : yscroll;

            write_ppu_scroll1 <= nmi_re;
            write_ppu_scroll2 <= write_ppu_scroll1;
        end
    end
    
    always_comb begin
        addr = 0;
        rw = 1;
        data_o = 0;
        if (read_ppu_ctrl) begin
            addr = 16'h2000;
            rw = 1;
        end else if (write_ppu_ctrl) begin
            rw = 0;
            addr = 16'h2000;
            data_o = PPU_CTRL;
        end else if (write_ppu_scroll1) begin
            rw = 0;
            addr = 16'h2005;
            data_o = xscroll;
        end else if (write_ppu_scroll2) begin
            rw = 0;
            addr = 16'h2005;
            data_o = yscroll;
        end
    end


endmodule