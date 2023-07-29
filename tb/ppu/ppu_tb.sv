`timescale 1ns/1ps

module ppu_tb #(
    parameter EXTERNAL_FRAME_TRIGGER=1,

    // sim timing
    parameter real FRAME_TIME = 1e9/60.0,
    parameter SIM_LENGTH = 2.25*FRAME_TIME

)();

    logic CLK_125MHZ, rst_clocks;

    initial begin
        CLK_125MHZ = 0;
        rst_clocks=1;
        #20;
        rst_clocks=0;
        #SIM_LENGTH;
        $finish;
    end
    initial begin
        // $dumpfile(`DUMP_WAVE_FILE);
        $dumpvars(0, ppu_tb);
    end

    logic frame_trigger;
    generate 
        if (EXTERNAL_FRAME_TRIGGER) begin
            logic [16:0] frame_ctr = 17'd89900;
            always_ff @(posedge clk_ppu) frame_ctr <= (frame_ctr == 17'd90000) ? 0 : frame_ctr + 1;
            assign frame_trigger = (frame_ctr == 0);
        end else begin
            assign frame_trigger = 0;
        end
    endgenerate


    wire clk_ppu, clk_cpu;
    wire rst_ppu, rst_cpu;
    wire [1:0] cpu_phase;
    clocks u_clocks(
        .CLK_125MHZ (CLK_125MHZ ),
        .rst_clocks  (rst_clocks    ),
        .clk_ppu    (clk_ppu    ),
        .clk_cpu    (clk_cpu    ),
        .cpu_phase    (cpu_phase    ),
        .rst_ppu    (rst_ppu    ),
        .rst_cpu    (rst_cpu    )
    );

    logic nmi, cpu_rw;
    logic [15:0] cpu_addr;
    wire [7:0] cpu_data_o;
    wire [7:0] cpu_data_i;

    cpu_sim 
    #(
        .SCROLLX_PER_FRAME (3 ),
        .SCROLLY_PER_FRAME (0 )
    )
    u_cpu_sim(
        .clk    (clk_cpu    ),
        .rst    (rst_cpu    ),
        .nmi    (nmi    ),
        .rw     (cpu_rw     ),
        .addr   (cpu_addr   ),
        .data_o (cpu_data_o ),
        .data_i (cpu_data_i )
    );

    // pulse cs for one ppu clock on tail end of cpu cycle
    wire cpu_ppu_cs = (cpu_phase==2) & (cpu_addr[15:13] == 3'h1);

    wire [2:0] cpu_ppu_addr = cpu_addr[2:0];
    logic [7:0] ppu_data_rd,ppu_data_wr;
    logic ppu_rd, ppu_wr;
    wire ppu_rw = !ppu_wr;

    logic [13:0] ppu_addr;
    logic [7:0] px_data;
    logic px_en, frame_sync;
    ppu #(
        .EXTERNAL_FRAME_TRIGGER (EXTERNAL_FRAME_TRIGGER)
        )
    u_ppu(
        .clk        (clk_ppu        ),
        .rst        (rst_ppu        ),
        .cpu_rw     (cpu_rw     ),
        .cpu_cs     (cpu_ppu_cs     ),
        .cpu_addr   (cpu_ppu_addr   ),
        .cpu_data_i (cpu_data_o ),
        .ppu_data_i (ppu_data_rd ),
        .cpu_data_o (cpu_data_i ),
        .nmi        (nmi        ),
        .ppu_addr_o   (ppu_addr   ),
        .ppu_data_o (ppu_data_wr ),
        .ppu_rd     (ppu_rd     ),
        .ppu_wr     (ppu_wr     ),
        .px_data    (px_data    ),
        .px_en    (px_en    ),
        .frame_trigger (frame_trigger ),
        .frame_sync (frame_sync )
    );

    mmap u_mmap(
        .clk    (clk_ppu    ),
        .rst    (rst_ppu    ),
        .addr   (ppu_addr   ),
        .rw     (ppu_rw     ),
        .data_i (ppu_data_wr ),
        .data_o (ppu_data_rd )
    );

    video u_video(
        .clk      (clk_ppu      ),
        .rst      (rst_ppu      ),
        .pixel    (px_data  ),
        .pixel_en (px_en ),
        .frame    (frame_sync)
    );

endmodule