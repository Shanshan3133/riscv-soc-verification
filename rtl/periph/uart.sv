// 8N1 UART, integer clock divider, one-byte RX holding register.
module uart #(parameter integer DEFAULT_DIV=868)(
 input logic clk,rst,rx, output logic tx,
 input logic req,we, input logic [7:0] offset,
 input logic [31:0] wdata, input logic [3:0] sel,
 output logic [31:0] rdata, output logic error,
 output wire tx_busy,rx_valid, output wire [7:0] rx_data
);
 logic [31:0] divider,tx_count,rx_count;
 logic [9:0] tx_shift;
 logic [3:0] tx_left;
 (* ASYNC_REG="TRUE" *) logic rx_meta,rx_sync;
 logic [1:0] rx_state;
 logic [2:0] rx_bit;
 logic [7:0] rx_shift,rx_byte;
 logic valid,overflow,frame_error;
 wire busy=tx_left!=0;
 assign tx_busy=busy;assign rx_valid=valid;assign rx_data=rx_byte;
 assign tx=busy ? tx_shift[0] : 1'b1;
 always_comb begin
   rdata=0; error=0;
   case(offset)
    0: begin if(we && busy) error=1; end
    4: begin rdata={24'b0,rx_byte}; if(we) error=1; end
    8: rdata={27'b0,frame_error,overflow,valid,busy,!busy};
    12: begin rdata=divider; if(we && (wdata<4 || busy || rx_state!=0 || sel!=15)) error=1; end
    default: error=1;
   endcase
 end
 always_ff @(posedge clk) begin
   if(rst) begin
    divider<=DEFAULT_DIV; tx_count<=0;tx_shift<=10'h3ff;tx_left<=0;
    rx_meta<=1;rx_sync<=1;rx_state<=0;rx_count<=0;rx_bit<=0;
    rx_shift<=0;rx_byte<=0;valid<=0;overflow<=0;frame_error<=0;
   end else begin
    rx_meta<=rx;rx_sync<=rx_meta;
    if(req && !error) begin
      if(we && offset==0 && sel[0]) begin
       tx_shift<={1'b1,wdata[7:0],1'b0}; tx_left<=10;tx_count<=divider-1;
      end
      if(!we && offset==4) valid<=0;
      if(we && offset==8 && sel[0]) begin
       if(wdata[3]) overflow<=0;
       if(wdata[4]) frame_error<=0;
      end
      if(we && offset==12) divider<=wdata;
    end
    if(busy) begin
      if(tx_count==0) begin
       tx_shift<={1'b1,tx_shift[9:1]}; tx_left<=tx_left-1;tx_count<=divider-1;
      end else tx_count<=tx_count-1;
    end
    case(rx_state)
     0: if(!rx_sync) begin rx_count<=(divider>>1)-1;rx_state<=1;end
     1: if(rx_count!=0) rx_count<=rx_count-1;
        else if(rx_sync) rx_state<=0;
        else begin rx_state<=2;rx_bit<=0;rx_count<=divider-1;end
     2: if(rx_count!=0) rx_count<=rx_count-1;
        else begin
         rx_shift[rx_bit]<=rx_sync;rx_count<=divider-1;
         if(rx_bit==7) rx_state<=3; else rx_bit<=rx_bit+1;
        end
     3: if(rx_count!=0) rx_count<=rx_count-1;
        else begin
         rx_state<=0;
         if(!rx_sync) frame_error<=1;
         else if(valid && !(req && !we && offset==4)) overflow<=1;
         else begin rx_byte<=rx_shift;valid<=1;end
        end
    endcase
   end
 end
endmodule
