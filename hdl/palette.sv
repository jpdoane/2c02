module palette #(
        parameter PAL_INIT="rom/smb_pal.rom"
    )(
    input logic clk, rst,
    input logic [4:0] addr,
    input logic wr,
    input logic [7:0] data_i,
    output logic [7:0] data_o
    );

    logic [7:0] PAL [31:0];

    integer file, cnt;
    initial begin
        if (PAL_INIT != "") begin
            file=$fopen(PAL_INIT,"rb");
            cnt = $fread(PAL, file, 0, 32);
            $display("Loaded %d bytes of PAL mem", cnt);
            // cnt=0;
            // while (cnt<32) cnt = cnt + $fread(PAL[cnt], file);
            $fclose(file);
        end
    end

    
     //Addresses $3F10/$3F14/$3F18/$3F1C are mirrors of $3F00/$3F04/$3F08/$3F0C.
     // if 2 lsbs are zero, then msb is 0 
    logic [4:0] addr_m;
    assign addr_m = {addr[4] & |addr[1:0], addr[3:0]};

    always_ff @(posedge clk) begin
        if (wr) PAL[addr_m] <= data_i;
        data_o <= PAL[addr_m];
    end

endmodule