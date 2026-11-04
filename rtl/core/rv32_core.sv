// RV32I execution engine. No privileged ISA; synchronous stop-on-trap EEI.
module rv32_core (
 input logic clk, rst, halt_req, resume, step,
 output logic halted, output logic [3:0] halt_reason,
 output logic [31:0] pc,
 output logic cyc, stb, we, output logic [31:0] addr, wdata,
 output logic [3:0] sel, input logic ack, err, input logic [31:0] rdata,
 input logic [4:0] dbg_reg_addr, output logic [31:0] dbg_reg_data,
 output logic retire_valid, output logic [31:0] retire_pc, retire_instr,
 output logic [4:0] retire_rd, output logic [31:0] retire_value,
 output logic retire_mem, retire_store, output logic [31:0] retire_addr, retire_data
);
 typedef enum logic [2:0] {BOUNDARY,FETCH,EXEC,MEM,COMMIT} state_t;
 state_t state;
 logic [31:0] regs [0:31];
 logic [31:0] instr, result, next_pc, mem_addr, mem_wdata;
 logic [4:0] dest;
 logic write_rd, mem_write, single_step;
 logic [2:0] mem_f3;
 logic [3:0] mem_sel;
 logic [31:0] a,b,ii,is,ib,iu,ij;
 logic [6:0] op,f7;
 logic [2:0] f3;
 logic [4:0] rd;
 logic [31:0] dec_result,dec_pc,ea, shifted;
 logic dec_write,dec_mem,dec_store,illegal,misalign,branch_taken;
 logic [3:0] trap;
 integer i;
 assign dbg_reg_data = dbg_reg_addr == 0 ? 0 : regs[dbg_reg_addr];
 always_comb begin
   op=instr[6:0]; f3=instr[14:12]; f7=instr[31:25]; rd=instr[11:7];
   a=instr[19:15]==0 ? 0 : regs[instr[19:15]];
   b=instr[24:20]==0 ? 0 : regs[instr[24:20]];
   ii={{20{instr[31]}},instr[31:20]};
   is={{20{instr[31]}},instr[31:25],instr[11:7]};
   ib={{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
   iu={instr[31:12],12'b0};
   ij={{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0};
   dec_result=0; dec_pc=pc+4; dec_write=0; dec_mem=0; dec_store=0;
   illegal=0; misalign=0; branch_taken=0; trap=0; ea=0;
   case(op)
    7'h37: begin dec_result=iu; dec_write=1; end
    7'h17: begin dec_result=pc+iu; dec_write=1; end
    7'h6f: begin dec_result=pc+4; dec_pc=pc+ij; dec_write=1; end
    7'h67: begin
      dec_result=pc+4; dec_pc=(a+ii)&32'hfffffffe; dec_write=1;
      if(f3!=0) illegal=1;
    end
    7'h63: begin
      case(f3)
       0: branch_taken=a==b; 1: branch_taken=a!=b;
       4: branch_taken=$signed(a)<$signed(b); 5: branch_taken=$signed(a)>=$signed(b);
       6: branch_taken=a<b; 7: branch_taken=a>=b;
       default: illegal=1;
      endcase
      if(branch_taken) dec_pc=pc+ib;
    end
    7'h13: begin
      dec_write=1;
      case(f3)
       0: dec_result=a+ii;
       2: dec_result={31'b0,($signed(a)<$signed(ii))};
       3: dec_result={31'b0,(a<ii)};
       4: dec_result=a^ii; 6: dec_result=a|ii; 7: dec_result=a&ii;
       1: begin dec_result=a<<instr[24:20]; if(f7!=0) illegal=1; end
       5: begin
         if(f7==0) dec_result=a>>instr[24:20];
         else if(f7==7'h20) dec_result=$signed(a)>>>instr[24:20];
         else illegal=1;
       end
      endcase
    end
    7'h33: begin
      dec_write=1;
      if(f7!=0 && !(f7==7'h20 && (f3==0 || f3==5))) illegal=1;
      case(f3)
       0: dec_result=f7==7'h20 ? a-b : a+b;
       1: dec_result=a<<b[4:0];
       2: dec_result={31'b0,($signed(a)<$signed(b))};
       3: dec_result={31'b0,(a<b)};
       4: dec_result=a^b;
       5: begin
         if(f7==7'h20) dec_result=$signed(a)>>>b[4:0];
         else dec_result=a>>b[4:0];
       end
       6: dec_result=a|b; 7: dec_result=a&b;
      endcase
    end
    7'h03,7'h23: begin
      dec_mem=1; dec_store=op==7'h23; dec_write=op==7'h03;
      ea=a+(dec_store ? is : ii);
      if(dec_store) begin if(f3>2) illegal=1; end
      else if(!(f3==0 || f3==1 || f3==2 || f3==4 || f3==5)) illegal=1;
      if((f3==1 || f3==5) && ea[0]) misalign=1;
      if(f3==2 && ea[1:0]!=0) misalign=1;
    end
    7'h0f: if(f3!=0) illegal=1; // FENCE: all earlier transactions completed.
    7'h73: begin
      if(instr==32'h00100073) trap=1;
      else if(instr==32'h00000073) trap=2;
      else illegal=1;
    end
    default: illegal=1;
   endcase
   if(illegal) trap=3;
   else if(dec_pc[1:0]!=0) trap=4;
   else if(misalign) trap=dec_store ? 6 : 5;
 end
 always_comb begin
   cyc=0; stb=0; we=0; addr=0; wdata=0; sel=4'b1111;
   if(state==FETCH) begin cyc=1; stb=1; addr=pc; end
   if(state==MEM) begin
     cyc=1; stb=1; we=mem_write; addr=mem_addr;
     wdata=mem_wdata; sel=mem_sel;
   end
   shifted=rdata>>(mem_addr[1:0]*8);
 end
 always_ff @(posedge clk) begin
   retire_valid<=0;
   if(rst) begin
     state<=BOUNDARY; halted<=1; halt_reason<=0; pc<=0; instr<=0;
     single_step<=0; result<=0; next_pc<=0; dest<=0; write_rd<=0;
     mem_addr<=0; mem_wdata<=0; mem_write<=0; mem_sel<=0; mem_f3<=0;
     retire_pc<=0; retire_instr<=0; retire_rd<=0; retire_value<=0;
     retire_mem<=0; retire_store<=0; retire_addr<=0; retire_data<=0;
     for(i=0;i<32;i=i+1) regs[i]<=0;
   end else begin
     case(state)
      BOUNDARY: begin
        if(halted) begin
          if((resume || step) && (halt_reason==0 || halt_reason==9)) begin
            halted<=0; halt_reason<=0; single_step<=step; state<=FETCH;
          end
        end else if(halt_req || single_step) begin halted<=1; halt_reason<=9; end
        else state<=FETCH;
      end
      FETCH: begin
        if(err) begin halted<=1; halt_reason<=7; state<=BOUNDARY; end
        else if(ack) begin instr<=rdata; state<=EXEC; end
      end
      EXEC: begin
        if(trap!=0) begin halted<=1; halt_reason<=trap; state<=BOUNDARY; end
        else begin
          result<=dec_result; next_pc<=dec_pc; dest<=rd; write_rd<=dec_write;
          mem_addr<=ea; mem_write<=dec_store; mem_f3<=f3;
          mem_wdata<=b<<(ea[1:0]*8);
          case(f3)
           0,4: mem_sel<=4'b0001<<ea[1:0];
           1,5: mem_sel<=4'b0011<<ea[1:0];
           default: mem_sel<=4'b1111;
          endcase
          retire_mem<=dec_mem; retire_store<=dec_store;
          if(dec_mem) state<=MEM; else state<=COMMIT;
        end
      end
      MEM: begin
        if(err) begin halted<=1; halt_reason<=8; state<=BOUNDARY; end
        else if(ack) begin
          if(!mem_write) begin
           case(mem_f3)
            0: result<={{24{shifted[7]}},shifted[7:0]};
            1: result<={{16{shifted[15]}},shifted[15:0]};
            2: result<=rdata;
            4: result<={24'b0,shifted[7:0]};
            5: result<={16'b0,shifted[15:0]};
            default: result<=0;
           endcase
          end
          state<=COMMIT;
        end
      end
      COMMIT: begin
        if(write_rd && dest!=0) regs[dest]<=result;
        retire_valid<=1; retire_pc<=pc; retire_instr<=instr;
        retire_rd<=write_rd ? dest : 0;
        retire_value<=(write_rd && dest!=0) ? result : 0;
        retire_addr<=mem_addr; retire_data<=mem_write ? mem_wdata : result;
        pc<=next_pc; state<=BOUNDARY;
      end
      default: begin halted<=1; halt_reason<=3; state<=BOUNDARY; end
     endcase
   end
 end
endmodule
