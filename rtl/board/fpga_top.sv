// 100 MHz board clock. CDC for reset release and GPIO; UART has its own CDC.
module fpga_top #(parameter PROG_HEX="",parameter integer UART_DIV=868)(
 input logic clk100,reset_button,debug_rx,uart_rx,
 output logic debug_tx,uart_tx,
 input logic [3:0] switches,output logic [3:0] leds,
 output logic [5:0] observe
);
 (* ASYNC_REG="TRUE" *) logic [1:0] reset_sync;
 (* ASYNC_REG="TRUE" *) logic [3:0] sw_meta,sw_sync;
 logic rst=1'b1;
 logic soc_reset,halt_req,resume,step,halted;
 logic [3:0] reason,mem_sel;
 logic [31:0] pc,reg_data,mem_addr,mem_wdata,mem_rdata,gpio;
 logic [4:0] reg_addr;
 logic mem_req,mem_we,mem_ack,mem_err,breq,back,bwe,rv;
 always_ff @(posedge clk100 or posedge reset_button)
  if(reset_button) reset_sync<=2'b11;else reset_sync<={reset_sync[0],1'b0};
 // The synchronizer asserts asynchronously, but BRAM control must only change
 // on a clock edge. This final, synchronous stage also times reset assertion.
 always_ff @(posedge clk100) rst<=reset_sync[1];
 always_ff @(posedge clk100) begin
  if(rst) begin sw_meta<=0;sw_sync<=0;end
  else begin sw_meta<=switches;sw_sync<=sw_meta;end
 end
 debug_bridge #(.UART_DIV(UART_DIV)) bridge(.clk(clk100),.rst,.rx(debug_rx),.tx(debug_tx),
  .soc_reset,.halt_req,.resume,.step,.halted,.halt_reason(reason),.pc,
  .reg_addr,.reg_data,.mem_req,.mem_we,.mem_addr,.mem_wdata,.mem_sel,.mem_ack,.mem_err,.mem_rdata);
 rv32_soc #(.PROG_HEX(PROG_HEX),.UART_DIV(UART_DIV)) soc(.clk(clk100),.rst(rst|soc_reset),
  .halt_req,.resume,.step,.halted,.halt_reason(reason),.pc,.dbg_reg_addr(reg_addr),.dbg_reg_data(reg_data),
  .dbg_req(mem_req),.dbg_we(mem_we),.dbg_addr(mem_addr),.dbg_wdata(mem_wdata),.dbg_sel(mem_sel),
  .dbg_ack(mem_ack),.dbg_err(mem_err),.dbg_rdata(mem_rdata),.uart_rx,.uart_tx,
  .gpio_in({28'b0,sw_sync}),.gpio_out(gpio),.retire_valid(rv),
  .retire_pc(),.retire_instr(),.retire_rd(),.retire_value(),.retire_mem(),.retire_store(),
  .retire_addr(),.retire_data(),.bus_req(breq),.bus_ack(back),.bus_we(bwe));
 assign leds=gpio[3:0];
 // Internal full-rate bus: capture with ILA. External pins are event indicators.
 assign observe={reason!=0,halted,rv,bwe,back,breq};
endmodule
