
module mmap #(
        parameter MIRRORV=1,
        parameter CHR_INIT="rom/smb_chr.rom",
        parameter VRAM_INIT="rom/smb_nt.rom"
    )(
    input logic clk, rst,
    input logic [13:0] addr,
    input logic rw,
    input logic [7:0] data_i,
    output logic [7:0] data_o
    );

    logic [7:0] CHR  [2**CHR_DEPTH-1:0];
    logic [7:0] VRAM [2**VRAM_DEPTH-1:0];

    integer file, cnt;
    initial begin
        if (CHR_INIT != "") begin
            file=$fopen(CHR_INIT,"rb");
            cnt = $fread(CHR, file, 0, 2**CHR_DEPTH);
            $display("Loaded %d bytes of CHR mem", cnt);
            // cnt=0;
            // while (cnt<2**CHR_DEPTH) cnt = cnt + $fread(CHR[cnt], file,0, 2**CHR_DEPTH);
            $fclose(file);
        end
        if (VRAM_INIT != "") begin
            file=$fopen(VRAM_INIT,"rb");
            cnt = $fread(VRAM, file, 0, 2**VRAM_DEPTH);
            $display("Loaded %d bytes of VRAM mem", cnt);
            // cnt=0;
            // while (cnt<2**VRAM_DEPTH) cnt = cnt + $fread(VRAM[cnt], file,0, 2**VRAM_DEPTH);
            $fclose(file);
        end
    end

    logic [7:0] v_data, c_data;

    logic cs, cs_r;                         // chip select, 1:CHR, 0:VRAM

    logic [CHR_DEPTH-1:0] chr_addr;
    assign cs = ~addr[13]; 
    assign chr_addr = addr[CHR_DEPTH-1:0];

    logic vram_topbit;
    logic [VRAM_DEPTH-1:0] vram_addr;
    assign vram_topbit = MIRRORV ? addr[VRAM_DEPTH-1] : addr[VRAM_DEPTH];
    assign vram_addr = {vram_topbit, addr[VRAM_DEPTH-2:0]};

    // VRAM mapping and mirroring:
    // Vertical mirroring: $2000 equals $2800 and $2400 equals $2C00 (e.g. Super Mario Bros.)
        // 14'h2000 = 14'h2800 = 14'b10_X000_0000_0000
        // 14'h2400 = 14'h2C00 = 14'b10_X100_0000_0000
    // Horizontal mirroring: $2000 equals $2400 and $2800 equals $2C00 (e.g. Kid Icarus)
        // 14'h2000 = 14'h2400 = 14'b10_0X00_0000_0000
        // 14'h2*00 = 14'h2C00 = 14'b10_1X00_0000_0000
    // One-screen mirroring: All nametables refer to the same memory at any given time, and the mapper directly manipulates CIRAM address bit 10 (e.g. many Rare games using AxROM)
        // 14'h2000 = 14'h2400 = 14'h2800 = 14'h2C00 =14'b10_XX00_0000_0000
    // Four-screen mirroring: CIRAM is disabled, and the cartridge contains additional VRAM used for all nametables (e.g. Gauntlet, Rad Racer 2)
    // Other: Some advanced mappers can present arbitrary combinations of CIRAM, VRAM, or even CHR ROM in the nametable area. Such exotic setups are rarely used.

    //CHR
    always @(posedge clk) begin
        c_data <= CHR[chr_addr];
        if (cs && ~rw) CHR[chr_addr] <= data_i;
        cs_r <= cs;
    end

    //VRAM
    always @(posedge clk) begin
        v_data <= VRAM[vram_addr];
        if (~cs && ~rw) VRAM[vram_addr] <= data_i;
    end

    // final mux
    always_comb begin
        data_o = cs_r ? c_data : v_data;
    end

endmodule