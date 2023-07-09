`timescale 1us/1ns

module ppu_tb ();

    logic clk, rst;

    logic cpu_rw=1;
    logic cpu_cs=0;
    logic [2:0] cpu_addr='0;
    logic [7:0] cpu_ppu_data='0;

    logic [7:0] ppu_cpu_data;
    logic nmi;
    logic [13:0] ppu_addr;
    logic [7:0] ppu_data_rd;
    logic [7:0] ppu_data_wr;
    logic ppu_rd, ppu_wr;
    logic frame_sync, px_en;
    logic [7:0] px_data;
    logic ppu_rw;

    logic [7:0] xscroll, yscroll;
    initial begin
        clk = 0;
        rst = 1;
        #4
        rst = 0; 

        // write ppuctrl
        #6
        cpu_addr=0;
        cpu_ppu_data=8'h1 << PPUCTRL_B; // upper nt
        cpu_rw = 0;
        cpu_cs = 1;
        #3
        cpu_cs = 0;
        // write ppuscroll (x)
        xscroll = 8'd0;
        yscroll = 8'd0;
        #3
        cpu_addr=3'h5;
        cpu_ppu_data=xscroll;
        cpu_rw = 0;
        cpu_cs = 1;
        // write ppuscroll (y)
        #3
        cpu_cs = 0;
        #3
        cpu_addr=3'h5;
        cpu_ppu_data=yscroll;
        cpu_rw = 0;
        cpu_cs = 1;
        #3
        cpu_cs = 0;
        #3
        cpu_rw = 1;
        cpu_cs = 0;

    end

    always #1 clk = ~clk;


    ppu u_ppu(
        .clk        (clk        ),
        .rst        (rst        ),
        .cpu_rw     (cpu_rw     ),
        .cpu_cs     (cpu_cs     ),
        .cpu_addr   (cpu_addr   ),
        .cpu_data_i (cpu_ppu_data ),
        .ppu_data_i (ppu_data_rd ),
        .cpu_data_o (ppu_cpu_data ),
        .nmi        (nmi        ),
        .ppu_addr_o   (ppu_addr   ),
        .ppu_data_o (ppu_data_wr ),
        .ppu_rd     (ppu_rd     ),
        .ppu_wr     (ppu_wr     ),
        .frame_sync (frame_sync ),
        .px_data    (px_data    ),
        .px_en    (px_en    )
    );





    assign ppu_rw = !ppu_wr;

    mmap 
    #(
        .CHR_INIT  ("rom/smb_chr.rom"  ),
        .VRAM_INIT ("rom/smb_nt.rom" )
    )
    u_mmap(
        .clk    (clk    ),
        .rst    (rst    ),
        .addr   (ppu_addr   ),
        .rw     (ppu_rw     ),
        .data_i (ppu_data_wr ),
        .data_o (ppu_data_rd )
    );


    video u_video(
        .clk      (clk      ),
        .rst      (rst      ),
        .pixel    (px_data  ),
        .pixel_en (px_en ),
        .frame    (frame_sync)
    );


    initial begin
        $dumpfile(`DUMP_WAVE_FILE);
        $dumpvars(0, ppu_tb);
    end

    // limit max sim duration
    initial begin
        // #700 // around a scanline
        #200000 // around a frame
        $display( "stopping...");
        $finish;
    end



endmodule