
module video #(
    parameter IMAGE_W=256,
    parameter IMAGE_H=240,
    parameter MAX_FRAMES=1000
    )
    (
    input logic clk, rst,
    input logic [7:0] pixel,
    input logic pixel_en,
    input logic frame
    );

    logic [23:0] pal [63:0];

    integer file, frame_cnt, cnt;
    string filename;
    initial begin
        $readmemh(`PALFILE, pal);
        frame_cnt = 0;
    end

    logic new_frame, file_open=0;
    logic frame_r;
    always @(posedge clk) begin
        if(rst) begin
            file_open <=0;
            new_frame <= 0;
        end else begin
            frame_r <= frame;
            new_frame <= frame & ~frame_r;
            file_open <= file_open;
            if (new_frame) begin
                if( file != 0) begin
                    $fclose(file);
                    $display("Closed %s at #%0t",filename, $realtime);
                    file=0;
                    file_open <= 0;
                    if (frame_cnt >= MAX_FRAMES) begin
                        $display("Processed %0d frame(s), terminating sim", frame_cnt);
                        $finish;
                    end
                end
                frame_cnt = frame_cnt+1;
                filename = $sformatf("frames/frame_%0d.ppm", frame_cnt);
                file=$fopen(filename,"w");        
                $fwrite(file,"P3\n");
                $fwrite(file,"%0d %0d\n",IMAGE_W, IMAGE_H);
                $fwrite(file,"%0d\n",2**8-1);
                $display("Writing %s",filename);
                file_open <= 1;
            end
        end
    end

    wire [23:0] px_rgb = pal[pixel[5:0]];
    wire [7:0] px_r = px_rgb[23:16];
    wire [7:0] px_g = px_rgb[15:8];
    wire [7:0] px_b = px_rgb[7:0];

    always @(posedge clk) begin
        if (file_open && pixel_en) begin
            $fwrite(file,"%0d %0d %0d\n",int'(px_r),int'(px_g),int'(px_b));
        end
    end

    final begin
        if( file != 0) begin
            $fclose(file);
            $display("Closed %s (prematurely) at #%0t",filename, $realtime);
        end
    end
endmodule