
module sprite #(parameter index=0)
    (
    input logic clk, rst,
    input logic [8:0] cycle,
    input logic eval,
    input logic px_en,
    input logic save_pat0,
    input logic save_pat1,
    input logic load_sr,
    input logic [7:0] at_i,
    input logic [7:0] pat_i,
    input logic [7:0] x_i,
    output logic [3:0] px,
    output logic pri
    );

    //sprite data registers
    logic [7:0] pat0;
    logic [7:0] pat1;
    logic [7:0] at;
    logic [7:0] x;

    wire sp_flip_x = at_i[6];
    wire [7:0] pat_rev = {pat_i[0],pat_i[1],pat_i[2],pat_i[3],pat_i[4],pat_i[5],pat_i[6],pat_i[7]};

    // save sprite data from oam2
    wire eval_this = eval && (cycle[5:3] == index);
    always @(posedge clk) begin
        if (rst) begin
            pat0 <= 0;
            pat1 <= 0;
            at <= 0;
            x <= 0;
        end else begin

            pat0 <= pat0;
            pat1 <= pat1;
            at <= at;
            x <= x;

            if (eval_this && save_pat0)
                pat0 <= sp_flip_x ? pat_rev : pat_i;
            if (eval_this && save_pat1) begin
                pat1 <= sp_flip_x ? pat_rev : pat_i;
                at <= at_i;
                x <= x_i;
            end
        end
    end

    // pixel shift registers and x counter
    logic [7:0] sr0, sr1, xc;
    // enable sprite once the counter reaches zero
    wire en = px_en && (xc==0);

    always @(posedge clk) begin
        if (rst) begin
            sr0 <= 0;
            sr1 <= 0;
            xc <= 0;
        end else begin
            sr0 <= load_sr ? pat0 : sr0;
            sr1 <= load_sr ? pat1 : sr1;

            xc <= px_en ? xc - 1 : x;

            if (en) begin
                sr0 <= sr0 << 1;
                sr1 <= sr1 << 1;
                xc <= xc;
            end
        end
    end

    assign px = {at[1:0], sr1[7]&en, sr0[7]&en};
    assign pri = at[5];


endmodule