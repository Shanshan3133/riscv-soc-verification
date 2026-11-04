`timescale 1ns/1ps
module tb_peripherals;
 logic clk=0;always #5 clk=~clk;
 logic rst=1,cyc=0,stb=0,we=0,ack,err,rx=1,tx;
 logic [31:0] addr=0,wdata=0,rdata,gpio_in=32'habcdef01,gpio_out;
 logic [3:0] sel=15;
 logic [31:0] result;logic failure;
 localparam DIV=16;
 soc_fabric #(.UART_DIV(DIV)) dut(.clk,.rst,.cyc,.stb,.we,.addr,.wdata,.sel,.ack,.err,.rdata,
  .uart_rx(rx),.uart_tx(tx),.gpio_in,.gpio_out);
 task automatic access(input bit wr,input [31:0] a,d,input [3:0] lanes,input bit expected_error);
  integer wait_cycles;
  begin
   @(negedge clk);cyc=1;stb=1;we=wr;addr=a;wdata=d;sel=lanes;wait_cycles=0;
   do begin @(negedge clk);wait_cycles=wait_cycles+1;if(wait_cycles>10)$fatal(1,"bus timeout");end while(!ack && !err);
   if(ack && err) $fatal(1,"ack and err overlap");
   if(err!==expected_error) $fatal(1,"wrong bus response addr=%h",a);
   result=rdata;
   // Keep request asserted after response to detect duplicate peripheral effects.
   repeat(3) begin @(negedge clk);if(ack || err) $fatal(1,"duplicate response");end
   cyc=0;stb=0;@(negedge clk);
  end
 endtask
 task automatic send_byte(input [7:0] data,input bit stop_bit);
  begin
   @(negedge clk);rx=0;repeat(DIV) @(negedge clk);
   for(integer bitno=0;bitno<8;bitno=bitno+1) begin rx=data[bitno];repeat(DIV) @(negedge clk);end
   rx=stop_bit;repeat(DIV) @(negedge clk);rx=1;repeat(DIV) @(negedge clk);
  end
 endtask
 task automatic check_tx(input [7:0] expected);
  logic [7:0] got;
  begin
   @(negedge tx);repeat(DIV+DIV/2) @(negedge clk);
   for(integer bitno=0;bitno<8;bitno=bitno+1) begin got[bitno]=tx;repeat(DIV) @(negedge clk);end
   if(got!==expected || tx!==1) $fatal(1,"TX frame got=%h expected=%h stop=%b",got,expected,tx);
  end
 endtask
 initial begin
  repeat(4) @(negedge clk);rst=0;
  access(1,32'h10000000,32'h12345678,15,0);
  access(1,32'h10000000,32'hffffab00,2,0);
  access(0,32'h10000000,0,15,0);if(result!==32'h1234ab78)$fatal(1,"RAM lanes");
  access(1,0,32'h00500093,15,0);access(0,0,0,15,0);if(result!==32'h00500093)$fatal(1,"program RAM");
  access(1,32'h20000100,32'h12345678,15,0);
  access(1,32'h20000100,32'h0000ff00,2,0);if(gpio_out!==32'h1234ff78)$fatal(1,"GPIO lanes");
  access(0,32'h20000104,0,15,0);if(result!==gpio_in)$fatal(1,"GPIO input");
  access(1,32'h20000104,0,15,1);access(0,32'h30000000,0,15,1);
  access(0,32'h20000101,0,15,1);access(0,32'h20000010,0,15,1);
  access(1,32'h2000000c,3,15,1);access(1,32'h2000000c,DIV,15,0);
  fork
   check_tx(8'ha6);
   begin
    access(1,32'h20000000,32'ha6,15,0);
    access(1,32'h20000000,32'hb7,15,1);
    access(1,32'h2000000c,DIV,15,1);
   end
  join
  repeat(DIV*2) @(negedge clk);
  send_byte(8'h81,1);access(0,32'h20000008,0,15,0);if(!result[2])$fatal(1,"RX valid");
  send_byte(8'h22,1);access(0,32'h20000008,0,15,0);if(!result[3])$fatal(1,"RX overflow");
  access(0,32'h20000004,0,15,0);if(result[7:0]!==8'h81)$fatal(1,"RX retains first byte");
  access(0,32'h20000008,0,15,0);if(result[2])$fatal(1,"RX read clear");
  access(1,32'h20000008,8,15,0);access(0,32'h20000008,0,15,0);if(result[3])$fatal(1,"overflow W1C");
  send_byte(8'h33,0);access(0,32'h20000008,0,15,0);if(!result[4])$fatal(1,"framing error");
  access(1,32'h20000008,16,15,0);access(0,32'h20000008,0,15,0);if(result[4])$fatal(1,"framing W1C");
  $display("PASS peripherals: BRAM, GPIO, UART TX/RX/busy/overflow/framing, bus errors");$finish;
 end
 initial begin #2000000;$fatal(1,"peripheral timeout");end
endmodule
