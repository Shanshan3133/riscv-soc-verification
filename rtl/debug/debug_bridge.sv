// Fixed 16-byte CRC16-CCITT frames. UART and command engine share clk.
module debug_bridge #(parameter integer UART_DIV=868, parameter integer FRAME_TIMEOUT=1000000)(
 input logic clk,rst,rx, output logic tx,
 output logic soc_reset,halt_req,resume,step,
 input logic halted, input logic [3:0] halt_reason,input logic [31:0] pc,
 output logic [4:0] reg_addr,input logic [31:0] reg_data,
 output logic mem_req,mem_we,output logic [31:0] mem_addr,mem_wdata,
 output logic [3:0] mem_sel,input logic mem_ack,mem_err,input logic [31:0] mem_rdata
);
 typedef enum logic [3:0] {RX,EXEC,WAIT_HALT,RESET_WAIT,RESET_SETTLE,BUS,BUS_GAP,RUNNING,CRC_REPLY,SEND} state_t;
 state_t state;
 logic [127:0] packet,response;
 logic [4:0] index,tx_index;
 logic [31:0] idle_count,run_count,run_limit;
 logic [15:0] crc;
 logic tx_busy,rx_valid,tx_gap,saw_running,timed_out;
 logic [7:0] rx_data;
 logic uart_req,uart_we,uart_error;
 logic [7:0] uart_offset;
 logic [31:0] uart_wdata,uart_rdata;
 function automatic [15:0] crc_byte(input [15:0] old_crc,input [7:0] value);
  reg [15:0] c;integer bitno;
  begin c=old_crc^{value,8'b0};for(bitno=0;bitno<8;bitno=bitno+1) c=c[15] ? (c<<1)^16'h1021 : c<<1;crc_byte=c;end
 endfunction
 function automatic [127:0] reply(input [7:0] cmd,seqno,status,input [31:0] rpc,data);
  reg [127:0] p;
  begin
   p=0;p[7:0]=8'ha5;p[15:8]=cmd|8'h80;p[23:16]=seqno;p[31:24]=status;
   p[63:32]=rpc;p[95:64]=data;
   p[119:112]=8'h5a;p[127:120]=8'hc3;reply=p;
  end
 endfunction
 task automatic respond(input [7:0] status,input [31:0] value);
  begin response<=reply(packet[15:8],packet[23:16],status,pc,value);tx_index<=0;crc<=16'hffff;state<=CRC_REPLY;end
 endtask
 uart #(.DEFAULT_DIV(UART_DIV)) transport(.clk,.rst,.rx,.tx,
  .req(uart_req),.we(uart_we),.offset(uart_offset),.wdata(uart_wdata),.sel(4'hf),
  .rdata(uart_rdata),.error(uart_error),.tx_busy,.rx_valid,.rx_data);
 always_comb begin
  uart_req=0;uart_we=0;uart_offset=8;uart_wdata=0;
  if(rx_valid) begin uart_req=1;uart_offset=4;end // discard unsolicited bytes while busy
  if(state==SEND && !tx_busy && !tx_gap) begin
   uart_req=1;uart_we=1;uart_offset=0;uart_wdata={24'b0,response[tx_index*8+:8]};
  end
  mem_req=state==BUS;mem_we=packet[15:8]==5;
  mem_addr=packet[63:32];mem_wdata=packet[95:64];mem_sel=4'hf;
  reg_addr=packet[68:64];
 end
 always_ff @(posedge clk) begin
  soc_reset<=0;resume<=0;step<=0;
  if(rst) begin
   state<=RX;packet<=0;response<=0;index<=0;tx_index<=0;crc<=16'hffff;
   idle_count<=0;run_count<=0;run_limit<=0;halt_req<=0;tx_gap<=0;
   saw_running<=0;timed_out<=0;
  end else begin
   if(tx_gap) tx_gap<=0;
   case(state)
    RX: begin
     if(index!=0) begin
      if(idle_count>=FRAME_TIMEOUT) begin index<=0;crc<=16'hffff;idle_count<=0;end
      else idle_count<=idle_count+1;
     end
     if(rx_valid) begin
      idle_count<=0;
      if(index==0) begin
       if(rx_data==8'ha5) begin packet[7:0]<=rx_data;index<=1;crc<=crc_byte(16'hffff,rx_data);end
      end else begin
       packet[index*8+:8]<=rx_data;
       if(index<12) crc<=crc_byte(crc,rx_data);
       if(index==15) begin
        index<=0;
        if(rx_data==8'hc3 && packet[119:112]==8'h5a && packet[111:96]==crc && packet[31:24]==0) state<=EXEC;
        crc<=16'hffff;
       end else index<=index+1;
      end
     end
    end
    EXEC: case(packet[15:8])
     1: begin halt_req<=1;state<=WAIT_HALT;end
     2: begin soc_reset<=1;state<=RESET_WAIT;end
     3: if(!halted) respond(2,0); else if(packet[95:64]>31) respond(1,0); else respond(0,reg_data);
     4,5: if(!halted) respond(2,0);else if(packet[33:32]!=0) respond(1,0);else state<=BUS;
     6,7: begin
      if(!halted || !(halt_reason==0 || halt_reason==9)) respond(2,0);
      else if(packet[15:8]==7 && packet[95:64]==0) respond(1,0);
      else begin
       if(packet[15:8]==6) step<=1;else resume<=1;
       run_limit<=packet[15:8]==6 ? 32'd100000 : packet[95:64];
       run_count<=0;saw_running<=0;timed_out<=0;state<=RUNNING;
      end
     end
     8: respond(0,{27'b0,halt_reason,halted});
     default: respond(1,0);
    endcase
    WAIT_HALT: if(halted) begin halt_req<=0;respond(0,{28'b0,halt_reason});end
    RESET_WAIT: begin halt_req<=0;state<=RESET_SETTLE;end
    RESET_SETTLE: respond(0,0);
    BUS: if(mem_ack || mem_err) begin
      response<=reply(packet[15:8],packet[23:16],mem_err ? 3 : 0,pc,mem_rdata);
      tx_index<=0;crc<=16'hffff;state<=BUS_GAP;
    end
    BUS_GAP: state<=CRC_REPLY;
    RUNNING: begin
     if(!halted) saw_running<=1;
     if(saw_running && halted) begin halt_req<=0;respond(timed_out ? 4 : 0,{28'b0,halt_reason});end
     else if(run_count>=run_limit) begin halt_req<=1;timed_out<=1;end
     else run_count<=run_count+1;
    end
    CRC_REPLY: begin
     crc<=crc_byte(crc,response[tx_index*8+:8]);
     if(tx_index==11) begin response[111:96]<=crc_byte(crc,response[tx_index*8+:8]);tx_index<=0;state<=SEND;end
     else tx_index<=tx_index+1;
    end
    SEND: if(!tx_busy && !tx_gap) begin
     tx_gap<=1;
     if(tx_index==15) begin state<=RX;index<=0;end
     else tx_index<=tx_index+1;
    end
    default: state<=RX;
   endcase
  end
 end
endmodule
