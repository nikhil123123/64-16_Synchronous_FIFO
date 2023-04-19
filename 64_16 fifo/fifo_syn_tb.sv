//transaction class
`timescale 1ns/1ps
class transaction;

rand bit rd_en, wr_en;
rand bit [15:0] data_in;
bit [15:0] data_out;
bit full, empty;

constraint wr_rd{                 

rd_en!=wr_en;
wr_en dist {0:/50, 1:/50};
rd_en dist {0:/50, 1:/50};  
}

constraint data_con{

data_in>1; data_in<5;
}


function void display(input string tag);
$display("[%0s] : WR : %0b\t RD:%0b\t DATAWR : %0d\t DATARD : %0d\t FULL : %0b\t EMPTY : %0b @ %0t", tag, wr_en, rd_en, data_in, data_out, full, empty,$time);   
endfunction


function transaction copy();
copy = new();
copy.rd_en = this.rd_en;
copy.wr_en = this.wr_en;
copy.data_in = this.data_in;
copy.data_out= this.data_out;
copy.full = this.full;
copy.empty = this.empty;
endfunction
  
endclass

module tb;
transaction tr;
initial begin
tr=new();
tr.display("TOP");
end
endmodule

//generator class

class generator;
  
transaction tr;  //handler
mailbox #(transaction) mbx;
  
int count = 0;
  
event next;  ///know when to send next transaction
event done;  ////conveys completion of requested no. of transaction
   
   
function new(mailbox #(transaction) mbx);
this.mbx = mbx;
tr=new();
endfunction; 
  
 //randomization 
 task run(); 
    
repeat(count)
	 
begin    
assert(tr.randomize) else $error("Randomization failed");	

mbx.put(tr.copy);
tr.display("GEN");

@(next);

end 

->done;

endtask

endclass

//Before writing the driver make interface in DUT

//Driver class

class driver;
  
virtual fifo_ift fif;
  
mailbox #(transaction) mbx;
  
transaction datac;
  
event next;
  
   
 
function new(mailbox #(transaction) mbx);
this.mbx = mbx;
endfunction; 
  
  ////reset DUT
task reset();
fif.rst <= 1'b1;
fif.rd_en <= 1'b0;
fif.wr_en <= 1'b0;
fif.data_in <= 0;

repeat(5) @(posedge fif.clk);
fif.rst <= 1'b0;
$display("[DRV] : DUT Reset Done");

endtask
   
  //////Applying RANDOM STIMULUS TO DUT
task run();
forever begin
mbx.get(datac);
      
datac.display("DRV");
      
fif.rd_en <= datac.rd_en;
fif.wr_en <= datac.wr_en;
fif.data_in <= datac.data_in;

repeat(2) @(posedge fif.clk);
->next;

end

endtask
  
endclass



class monitor;
 
virtual fifo_ift fif;

// we require a mailbox because we want to recieve a transaction from a generator
  
mailbox #(transaction) mbx;

transaction tr;

function new(mailbox #(transaction) mbx);
this.mbx = mbx;     
endfunction;
  
  
task run();
tr = new();
    
forever begin
repeat(2) @(posedge fif.clk);
tr.wr_en = fif.wr_en;
tr.rd_en = fif.rd_en;
tr.data_in = fif.data_in;
tr.data_out = fif.data_out;
tr.full = fif.full;
tr.empty = fif.empty;
      
      
mbx.put(tr);
      
tr.display("MON");
 
end
    
endtask
  
  
endclass 
 

class scoreboard;
  
mailbox #(transaction) mbx;
  
transaction tr;    // tr is data container
  
event next;
  
bit [7:0] din[$];   // working with queue- din is the name of queue
bit[7:0] temp;
  
function new(mailbox #(transaction) mbx);
this.mbx = mbx;     
endfunction;
  
  
task run();
    
forever begin
    
mbx.get(tr);
    
tr.display("SCO");
    
if(tr.wr_en == 1'b1)
begin 
din.push_front(tr.data_in);    //push_front add new data in front of the queue
$display("[SCO] : DATA STORED IN QUEUE :%0d", tr.data_in);
end
    
if(tr.rd_en == 1'b1)
begin
if(tr.empty == 1'b0) begin 
          
temp = din.pop_back();  // pop_back give out the data
          
if(tr.data_out == temp)
$display("[SCO] : DATA MATCH");
else
$error("[SCO] : DATA MISMATCH");
end
else 
begin
$display("[SCO] : FIFO IS EMPTY");
end
        
        
end
    
->next;
  end
  endtask
 
  
endclass


class environment;
 
generator gen;
driver drv;
  
monitor mon;
scoreboard sco;
  
mailbox #(transaction) gdmbx; ///generator + Driver
    
mailbox #(transaction) msmbx; ///Monitor + Scoreboard
 
event nextgs;
 
 
virtual fifo_ift fif;
  
  
function new(virtual fifo_ift fif);
 
    
gdmbx = new();
gen = new(gdmbx);
drv = new(gdmbx);
    
    
    
    
msmbx = new();
mon = new(msmbx);
sco = new(msmbx);
    
    
this.fif = fif;   
    
drv.fif = this.fif;
mon.fif = this.fif;
    
    
gen.next = nextgs;
sco.next = nextgs;
 
endfunction
  
  
  
task pre_test();
drv.reset();
endtask
  
task test();
fork
gen.run();
drv.run();
mon.run();
sco.run();
join_any
    
endtask
  
task post_test();
wait(gen.done.triggered);  
$finish();
endtask
  
task run();
pre_test();
test();
post_test();
endtask
  
  
  
endclass


 module tb;
    
   
fifo_ift fif();
fifo dut (fif.clk, fif.rd_en, fif.wr_en,fif.full, fif.empty, fif.data_in, fif.data_out, fif.rst);
    
initial begin
fif.clk <= 0;
end
    
always #10 fif.clk <= ~fif.clk;
    
environment env;
    
    
    
initial begin
env = new(fif);
env.gen.count = 20;    //number of transactions that we want to send to DUT
env.run();
end
      
    
initial begin
$dumpfile("dump.vcd");
$dumpvars;
end
   
    
endmodule

