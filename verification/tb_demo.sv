`timescale 1ns/1ps
module tb_demo;
 logic clk=0;always #5 clk=~clk;
 logic rst=1,resume=0,halted,tx;
 logic [3:0] reason;logic [31:0] pc,gpio;
 integer seen=0;logic [7:0] got;
 logic [7:0] message[0:9];
 localparam DIV=16;
 rv32_soc #(.PROG_HEX("firmware/demo.hex"),.UART_DIV(DIV)) dut(.clk,.rst,.halt_req(1'b0),.resume,.step(1'b0),
  .halted,.halt_reason(reason),.pc,.dbg_reg_addr(5'b0),.dbg_reg_data(),
  .dbg_req(1'b0),.dbg_we(1'b0),.dbg_addr(32'b0),.dbg_wdata(32'b0),.dbg_sel(4'hf),
  .dbg_ack(),.dbg_err(),.dbg_rdata(),.uart_rx(1'b1),.uart_tx(tx),
  .gpio_in(32'b0),.gpio_out(gpio),.retire_valid(),.retire_pc(),.retire_instr(),
  .retire_rd(),.retire_value(),.retire_mem(),.retire_store(),.retire_addr(),.retire_data(),
  .bus_req(),.bus_ack(),.bus_we());
 initial begin
  message[0]="R";message[1]="V";message[2]="3";message[3]="2";message[4]="I";
  message[5]=" ";message[6]="O";message[7]="K";message[8]=13;message[9]=10;
  repeat(4) @(negedge clk);rst=0;resume=1;@(negedge clk);resume=0;
  wait(!halted);wait(halted);@(negedge clk);
  if(reason!==1 || pc!==232 || gpio!==15 || seen!=10) $fatal(1,"demo state reason=%d pc=%h gpio=%h bytes=%d",reason,pc,gpio,seen);
  $display("PASS demo: CPU program emitted RV32I OK, GPIO=15, EBREAK");$finish;
 end
 initial forever begin
  @(negedge tx);repeat(DIV+DIV/2) @(negedge clk);
  for(integer b=0;b<8;b=b+1) begin got[b]=tx;repeat(DIV) @(negedge clk);end
  if(seen>=10 || got!==message[seen] || tx!==1) $fatal(1,"demo UART byte %d got=%h",seen,got);
  seen=seen+1;
 end
 initial begin #2000000;$fatal(1,"demo timeout");end
endmodule
