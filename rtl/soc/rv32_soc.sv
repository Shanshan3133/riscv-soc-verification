module rv32_soc #(parameter PROG_HEX="", parameter integer UART_DIV=868)(
 input logic clk,rst,halt_req,resume,step,
 output logic halted, output logic [3:0] halt_reason, output logic [31:0] pc,
 input logic [4:0] dbg_reg_addr, output logic [31:0] dbg_reg_data,
 input logic dbg_req,dbg_we, input logic [31:0] dbg_addr,dbg_wdata,
 input logic [3:0] dbg_sel, output logic dbg_ack,dbg_err, output logic [31:0] dbg_rdata,
 input logic uart_rx, output logic uart_tx,
 input logic [31:0] gpio_in, output logic [31:0] gpio_out,
 output logic retire_valid, output logic [31:0] retire_pc,retire_instr,
 output logic [4:0] retire_rd, output logic [31:0] retire_value,
 output logic retire_mem,retire_store, output logic [31:0] retire_addr,retire_data,
 output logic bus_req,bus_ack,bus_we
);
 logic ccyc,cstb,cwe,ack,err;
 logic [31:0] caddr,cwdata,rdata;
 logic [3:0] csel;
 wire grant=halted && !ccyc;
 wire request=grant ? dbg_req : ccyc;
 assign dbg_ack=grant && ack;
 assign dbg_err=(grant && err);
 assign dbg_rdata=rdata;
 assign bus_req=request;assign bus_ack=ack;assign bus_we=grant ? dbg_we : cwe;
 rv32_core cpu(.clk,.rst,.halt_req,.resume,.step,.halted,.halt_reason,.pc,
  .cyc(ccyc),.stb(cstb),.we(cwe),.addr(caddr),.wdata(cwdata),.sel(csel),
  .ack(ack && !grant),.err(err && !grant),.rdata,.dbg_reg_addr,.dbg_reg_data,
  .retire_valid,.retire_pc,.retire_instr,.retire_rd,.retire_value,
  .retire_mem,.retire_store,.retire_addr,.retire_data);
 soc_fabric #(.PROG_HEX(PROG_HEX),.UART_DIV(UART_DIV)) fabric(.clk,.rst,
  .cyc(request),.stb(grant ? dbg_req : cstb),.we(grant ? dbg_we : cwe),
  .addr(grant ? dbg_addr : caddr),.wdata(grant ? dbg_wdata : cwdata),
  .sel(grant ? dbg_sel : csel),.ack,.err,.rdata,.uart_rx,.uart_tx,.gpio_in,.gpio_out);
endmodule
