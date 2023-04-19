`timescale 1ns/1ps
module fifo(full,empty,data_out,clk,rst,wr_en,rd_en,data_in);
input clk, rst, wr_en, rd_en;
input [15:0] data_in;

output reg [15:0] data_out;
output reg full, empty;


reg [6:0] counter, rd_ptr, wr_ptr;
reg [15:0] mem [63:0];

// initialize empty and full reg 

integer i;

always @(counter) begin
empty= (counter==0);
full= (counter==64);
end

//reset counter and fifo memory

always @(posedge clk or posedge rst) begin       // --asynchronous
if(rst) begin
counter<=7'b0000000;
for(i=0; i<64; i=i++) begin
mem [i]<=16'd0;
end
end

//when read and write operation are performed at same time so updating counter

else if((!full && wr_en) && (!empty && rd_en)) begin
counter<=counter;
end

//for write operation checking and updating the counter

else if (!full && wr_en) begin
counter<=counter+1;
end

// for read operation checking and updating the counter

else if (!empty && rd_en) begin
counter<=counter-1;
end

else begin
counter<=counter;
end
end


//read operation

always@(posedge clk or posedge rst) begin
if(rst) begin
data_out<=16'd0;
end
else begin
	if(rd_en && !empty) begin
	data_out<=mem[rd_ptr];
	end
	else begin
	data_out<=data_out;
	end
end
end

// write operation

always @(posedge clk) begin
    
        if ( wr_en && !full ) begin
            mem[wr_ptr] <= data_in;
        end
        else begin
            mem[wr_ptr] <= mem[wr_ptr];
        end
    
end

//pointer updation

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr <= 7'd0;
        rd_ptr <= 7'd0;
    end
    else begin
        if (rd_en && !empty) begin
            rd_ptr<=rd_ptr + 1;
        end
        else begin
            rd_ptr<=rd_ptr;
        end
        if (wr_en && !full) begin
             wr_ptr <= wr_ptr + 1;
             end
        else begin
             wr_ptr <= wr_ptr;
             end
    end
end

endmodule

interface fifo_ift;
  
  logic clk, rd_en, wr_en;
  logic full, empty;
  logic [7:0] data_in;
  logic [7:0] data_out;
  logic rst; 
 
endinterface
