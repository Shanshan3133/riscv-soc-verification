`timescale 1ns/1ps
module tb_debug;
 localparam DIV=16;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,rx=1,tx;
 logic [3:0] switches=0,leds;logic [5:0] observe;
 fpga_top #(.UART_DIV(DIV)) dut(.clk100(clk),.reset_button(reset),.debug_rx(rx),.debug_tx(tx),
  .uart_rx(1'b1),.uart_tx(),.switches,.leds,.observe);
 defparam dut.bridge.FRAME_TIMEOUT=5000;
 logic [127:0] received;
 logic [7:0] rxbyte;
 integer captured=0;
 string frames_path,responses_path;
 logic [127:0] frames[0:255];
 integer num_frames=0,response_fd;
 // Receive in a concurrent monitor so immediate replies cannot be missed.
 initial forever begin
  @(negedge tx);repeat(DIV+DIV/2) @(negedge clk);
  for(integer b=0;b<8;b=b+1) begin rxbyte[b]=tx;repeat(DIV) @(negedge clk);end
  if(tx!==1) $fatal(1,"debug response framing");
  received[(captured%16)*8+:8]=rxbyte;captured=captured+1;
  if(captured%16==0) $fdisplay(response_fd,"%032x",received);
 end
 task automatic send_byte(input [7:0] data);
  begin
   @(negedge clk);rx=0;repeat(DIV) @(negedge clk);
   for(integer bitno=0;bitno<8;bitno=bitno+1) begin rx=data[bitno];repeat(DIV) @(negedge clk);end
   rx=1;repeat(DIV) @(negedge clk);
  end
 endtask
 initial begin
  if(!$value$plusargs("FRAMES=%s",frames_path)) $fatal(1,"FRAMES required");
  if(!$value$plusargs("RESPONSES=%s",responses_path)) $fatal(1,"RESPONSES required");
  if(!$value$plusargs("COUNT=%d",num_frames)) $fatal(1,"COUNT required");
  response_fd=$fopen(responses_path,"w");$readmemh(frames_path,frames,0,num_frames-1);
  repeat(5) @(negedge clk);reset=0;repeat(5) @(negedge clk);
  // Truncated command must expire without side effects or a response.
  send_byte(8'ha5);send_byte(8'h05);send_byte(8'hc8);send_byte(8'h00);
  repeat(6000) @(negedge clk);
  for(integer f=0;f<num_frames;f=f+1) begin
   for(integer byteidx=0;byteidx<16;byteidx=byteidx+1) send_byte(frames[f][byteidx*8+:8]);
   // Enough for UART response plus bounded RUN. Invalid frames produce none.
   repeat(6000) @(negedge clk);
  end
  $fclose(response_fd);$display("PASS debug transport simulation: %0d response bytes",captured);$finish;
 end
 initial begin #100000000;$fatal(1,"debug timeout");end
endmodule
