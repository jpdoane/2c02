
module ppu
    (
    input logic clk, rst,
    input logic cpu_rw, cpu_cs,
    input logic [2:0] cpu_addr,
    input logic [7:0] cpu_data_i,
    input logic [7:0] ppu_data_i,

    output logic [7:0] cpu_data_o,
    output logic nmi,
    output logic [13:0] ppu_addr_o,
    output logic [7:0] ppu_data_o,
    output logic ppu_rd, ppu_wr,

    output logic frame_sync,
    output logic [7:0] px_data,
    output logic px_en
    );

    logic reg_re, reg_we, cs_r;

    // cs re detection
    always @(posedge clk) begin
        if (rst) begin
            cs_r <= 0;
        end else begin
            cs_r <= cpu_cs;
        end
    end
    assign reg_re = cpu_cs & ~cs_r & cpu_rw;
    assign reg_we = cpu_cs & ~cs_r & ~cpu_rw;

    // cpu/ppu read / write registers
    logic cpu_ppu_read;
    logic [7:0] cpu_data_io, cpu_readbuf;
    always @(posedge clk) begin
        if (rst) begin
            ppu_data_o <= 0;
            cpu_readbuf <= 0;
        end else begin
            ppu_data_o <= ppu_wr ? cpu_data_io : 0;
            cpu_readbuf <= cpu_ppu_read ? ppu_data_i : cpu_readbuf;
        end
    end
    assign cpu_data_o = cpu_data_io;

    // signals from render...
    logic fetch_attr, fetch_chr;
    logic [12:0] pattern_idx;
    logic [4:0] palette_idx;
    logic rend, vblank, vblank_clr, inc_cx, inc_y, return00;
    logic sp0, sp_of;

    // v/t: registers
    // yyy NN YYYYY XXXXX
    // ||| || ||||| +++++-- coarse X scroll
    // ||| || +++++-------- coarse Y scroll
    // ||| ++-------------- nametable select
    // +++----------------- fine Y scroll

    logic [14:0] v,t; // permanent and temporary address register
    logic [2:0] fine_x;    // fine x
    logic w;          // 1st vs 2nd write toggle (for two byte registers)
    logic [7:0] ppuctrl,ppumask,ppudata;
    // logic [7:0] oamaddr,oamdata,oamdma;

    logic inc_v;                     // signal to increment v pointer

    logic updatevh, updatevv;

    logic rst_delay;


    assign ppu_rd = ~ppu_wr;
    always @(posedge clk) begin
        if (rst) begin
            ppuctrl <= 0;
            ppumask <= 0;
            // oamaddr <= 0;
            // oamdata <= 0;
            // oamdma <= 0;
            rst_delay <= 1;

            cpu_data_io <= 0;
            updatevh <= 0;
            updatevv <= 0;

            v <= 0;
            t <= 0;
            fine_x <= 0;
            w <= 0;
            inc_v<=0;
            ppu_wr <= 0;
            cpu_ppu_read <= 0;
            vblank_clr <= 0;
        end else begin
            ppuctrl <= ppuctrl;
            ppumask <= ppumask;
            // oamaddr <= oamaddr;
            // oamdata <= oamdata;
            // oamdma <= oamdma;

            v <= v;
            t <= t;
            fine_x<= fine_x;
            inc_v <= 0;
            vblank_clr <= vblank_clr && vblank;

            cpu_data_io <= cpu_data_io;       // output data will be maintained, emulating ppu i/o latch
                                            // input data is also copied to data_o on writes

            cpu_ppu_read <= 0;
            if(reg_re) begin    // cpu read (ppu write back to cpu)
                case(cpu_addr)
                    PPUSTATUS_ADDR: begin
                                    cpu_data_io[7:5] <= {vblank && ~vblank_clr, sp0, sp_of}; //bits 4:0 maintain latched data
                                    vblank_clr <= 1;            // clear vblank after read
                                    w <= 0;                     // reset write toggle
                                    end
                    // OAMDATA_ADDR:   cpu_data_io <= oamdata;
                    PPUDATA_ADDR:   begin
                                    cpu_data_io <= vpal ? pal_data : cpu_readbuf;
                                    cpu_ppu_read <= 1;  // update cpu_readbuf with incoming data
                                    end
                endcase
            end

            if(reg_we) begin    // cpu write (ppu store or write to vram)
                cpu_data_io <= cpu_data_i;   //emulate latching io bus
                case(cpu_addr)
                    PPUCTRL_ADDR:   begin
                                        t[11:10] <= cpu_data_i[1:0];  // nametable select
                                        ppuctrl <= cpu_data_i;
                                    end
                    // PPUMASK_ADDR:   ppumask <= cpu_data_i;
                    // OAMADDR_ADDR:   oamaddr <= cpu_data_i;
                    // OAMDATA_ADDR:   oamdata <= cpu_data_i;
                    PPUSCROLL_ADDR: begin
                                    if (~w) begin
                                        t[4:0] <= cpu_data_i[7:3];  // coarse x
                                        fine_x <= cpu_data_i[2:0];       // fine x
                                    end else begin
                                        t[9:5] <= cpu_data_i[7:3];   // coarse y
                                        t[14:12] <= cpu_data_i[2:0]; // fine y
                                    end
                                    w = ~w;
                                    end
                    PPUADDR_ADDR:   if (!rst_delay) begin
                                    if (~w) begin
                                        // high addr
                                        t[14:8] <= {1'b0, cpu_data_i[5:0]};
                                    end else begin
                                        // low addr
                                        t[7:0] <= cpu_data_i;
                                        v <= {t[14:8], cpu_data_i};
                                    end
                                    w = ~w;
                                    end
                    PPUDATA_ADDR:   begin
                                    pal_wr <= vpal;
                                    ppu_wr <= ~vpal;
                                    inc_v <= 1;
                                    end
                endcase
            end

            // these registers are held in delayed reset
            // if (rst_delay) begin
            //     ppuctrl <= 0;
            //     ppumask <= 0;
            //     t <= 0;
            //     fine_x <= 0;
            //     w <= 0;
            // end

            // increment from reg r/w
            if (inc_v & ~rend) v <= ppuctrl[PPUCTRL_I] ? v + 'h20 : v + 1;

            // increment y
            if (inc_y | (rend && inc_v)) begin
                if (&v[14:12]) begin                //fine y will wrap
                    if (v[9:5] == 5'd29) begin      //coarse y will wrap                
                        v[9:5] <= 0;              
                        v[11] <= ~v[11];            //switch vertical nametable
                    end else if (&v[9:5]) begin     // coarse y is OOB
                        v[9:5] <= 0;                // wrap w/o flipping table                        
                    end else begin
                        v[9:5] <= v[9:5] + 1;       //inc coarse y
                    end
                end
                v[14:12] <= v[14:12] + 1;           //inc fine y
            end
            updatevh <= inc_y;                      //update horizonal info on scan line increment
            updatevv <= 0;                          //only used by return00

            // increment coarse x
            if (inc_cx | (rend && inc_v)) begin
                if(&v[4:0]) v[10] <= ~v[10];        //switch horizontal nametable
                v[4:0] <= v[4:0] + 1;               //inc coarse x
            end

            // update v horizontal info
            if (updatevh || return00) begin
                v[10] <= t[10];
                v[4:0] <= t[4:0];
            end
            // update v vertical info
            if (updatevv || return00) begin
                v[11] <= t[11];
                v[14:12] <= t[14:12];
                v[9:5] <= t[9:5];
            end

        end
    end


    // address is generally taken from v unless fetch_attr or fetch_chr set
    logic [13:0] addr, attr_addr, chr_addr;
    assign chr_addr = {1'b0, pattern_idx};
    assign attr_addr = {2'h2, v[11:10], 4'b1111, v[9:7], v[4:2]};
    assign ppu_addr_o = fetch_attr ? attr_addr :
                        fetch_chr ? chr_addr :
                        {2'h2, v[11:0]};

    wire lower_tile = v[6];
    wire left_tile = v[1];
    wire [1:0] attr_decode = lower_tile ? left_tile ? ppu_data_i[7:6] : ppu_data_i[5:4]: //lower left / right tile
                                          left_tile ? ppu_data_i[3:2] : ppu_data_i[1:0]; //upper left / right tile



    render u_render(
        .clk         (clk         ),
        .rst         (rst         ),
        // .sp_id       (sp_id       ),
        // .sp_attr     (sp_attr     ),
        // .sp_data     (sp_data     ),
        .fine_x (fine_x),
        .ppuctrl     (ppuctrl     ),
        .data_i      (ppu_data_i      ),
        .attr_i      (attr_decode),
        .fetch_attr  (fetch_attr  ),
        .fetch_chr   (fetch_chr   ),
        .pattern_idx (pattern_idx ),
        .palette_idx (palette_idx ),
        .px_en       (px_en       ),
        .rend        (rend      ),
        .vblank      (vblank      ),
        .inc_cx      (inc_cx      ),
        .inc_y      (inc_y      ),
        .sp0        (sp0),
        .sp_of      (sp_of),
        .return00 (return00)
    );


    // palette memory
    // palette index is generally obtained from render unless v is pointing to pallete address
    logic pal_wr, vpal;
    logic [7:0] pal_data;
    logic [4:0] pal_addr;
    assign vpal = (v[13:8] == 6'h3f);
    assign pal_addr = vpal ? v[4:0] : palette_idx;
    
    palette  u_palette(
        .clk    (clk    ),
        .rst    (rst    ),
        .addr   (pal_addr   ),
        .wr     (pal_wr   ),
        .data_i (cpu_data_io ),
        .data_o (pal_data )
    );

    assign px_data = pal_data & {8{px_en}};
    assign frame_sync = return00;


endmodule