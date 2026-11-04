module soc_fabric #(parameter PROG_HEX="", parameter integer UART_DIV=868)(
 input logic clk,rst,cyc,stb,we,
 input logic [31:0] addr,wdata, input logic [3:0] sel,
 output logic ack,err, output logic [31:0] rdata,
 input logic uart_rx, output logic uart_tx,
 input logic [31:0] gpio_in, output logic [31:0] gpio_out
);
 (* ram_style="block" *) logic [31:0] imem[0:4095];
 (* ram_style="block" *) logic [31:0] dmem[0:4095];
 logic holdoff;
 logic [31:0] uart_data;
 logic [31:0] imem_read,dmem_read,aux_data;
 logic [1:0] response_target;
 logic uart_error;
 wire request=cyc && stb && !holdoff;
 wire is_imem=addr[31:14]==0;
 wire is_dmem=addr[31:14]==18'h04000;
 wire is_uart=addr[31:8]==24'h200000;
 wire is_gpio=addr[31:8]==24'h200001;
 wire uart_req=request && is_uart && addr[1:0]==0;
 integer n;
 initial begin
   for(n=0;n<4096;n=n+1) begin imem[n]=32'h00100073;dmem[n]=0;end
   if(PROG_HEX!="") $readmemh(PROG_HEX,imem);
 end
 uart #(.DEFAULT_DIV(UART_DIV)) u_uart(.clk,.rst,.rx(uart_rx),.tx(uart_tx),
   .req(uart_req),.we,.offset(addr[7:0]),.wdata,.sel,.rdata(uart_data),.error(uart_error));
 // Dedicated synchronous read ports allow inference of real FPGA block RAM.
 always_ff @(posedge clk) begin
   imem_read<=imem[addr[13:2]];
   dmem_read<=dmem[addr[13:2]];
 end
 always_comb begin
   case(response_target)
    0:rdata=imem_read;
    1:rdata=dmem_read;
    default:rdata=aux_data;
   endcase
 end
 always_ff @(posedge clk) begin
   ack<=0;err<=0;
   if(rst) begin holdoff<=0;aux_data<=0;response_target<=2;gpio_out<=0;end
   else begin
    if(!cyc || !stb) holdoff<=0;
    if(request) begin
     holdoff<=1;
     if(is_imem || is_dmem) begin
       ack<=1;
       if(is_imem) begin
        response_target<=0;
        if(we) begin
         if(sel[0]) imem[addr[13:2]][7:0]<=wdata[7:0];
         if(sel[1]) imem[addr[13:2]][15:8]<=wdata[15:8];
         if(sel[2]) imem[addr[13:2]][23:16]<=wdata[23:16];
         if(sel[3]) imem[addr[13:2]][31:24]<=wdata[31:24];
        end
       end else begin
        response_target<=1;
        if(we) begin
         if(sel[0]) dmem[addr[13:2]][7:0]<=wdata[7:0];
         if(sel[1]) dmem[addr[13:2]][15:8]<=wdata[15:8];
         if(sel[2]) dmem[addr[13:2]][23:16]<=wdata[23:16];
         if(sel[3]) dmem[addr[13:2]][31:24]<=wdata[31:24];
        end
       end
     end else if(addr[1:0]!=0) err<=1;
     else if(is_uart) begin err<=uart_error;ack<=!uart_error;response_target<=2;aux_data<=uart_data;end
     else if(is_gpio) begin
      if(addr[7:0]==0) begin
       ack<=1;response_target<=2;aux_data<=gpio_out;
       if(we) begin
        if(sel[0]) gpio_out[7:0]<=wdata[7:0];
        if(sel[1]) gpio_out[15:8]<=wdata[15:8];
        if(sel[2]) gpio_out[23:16]<=wdata[23:16];
        if(sel[3]) gpio_out[31:24]<=wdata[31:24];
       end
      end else if(addr[7:0]==4 && !we) begin ack<=1;response_target<=2;aux_data<=gpio_in;end
      else err<=1;
     end else err<=1;
    end
   end
 end
endmodule
