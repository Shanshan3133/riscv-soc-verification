`timescale 1ns/1ps
module tb_core;
 logic clk=0; always #5 clk=~clk;
 logic rst=1,halt_req=0,resume=0,step=0,halted;
 logic [3:0] reason,sel;
 logic [31:0] pc,addr,wdata,rdata=0,dbg_data;
 logic cyc,stb,we,ack=0,err=0,rv,rm,rs;
 logic [31:0] rp,ri,rval,ra,rmd;
 logic [4:0] rd,dbg_addr=0;
 logic [31:0] imem[0:4095],dmem[0:4095];
 integer delay_max=0,seed=1,countdown=0,cycles=0,trace_fd,n,regs_fd,reason_fd,wait_observed=0;
 logic pending=0,served=0;
 logic [31:0] saved_addr,saved_data;logic [3:0] saved_sel;logic saved_we;
 string image,trace_path,regs_path,reason_path,vcd_path;
 rv32_core dut(.clk,.rst,.halt_req,.resume,.step,.halted,.halt_reason(reason),.pc,
  .cyc,.stb,.we,.addr,.wdata,.sel,.ack,.err,.rdata,
  .dbg_reg_addr(dbg_addr),.dbg_reg_data(dbg_data),.retire_valid(rv),
  .retire_pc(rp),.retire_instr(ri),.retire_rd(rd),.retire_value(rval),
  .retire_mem(rm),.retire_store(rs),.retire_addr(ra),.retire_data(rmd));
 initial begin
  for(n=0;n<4096;n=n+1) begin imem[n]=32'h00100073;dmem[n]=0;end
  if(!$value$plusargs("IMAGE=%s",image)) $fatal(1,"IMAGE required");
  if(!$value$plusargs("TRACE=%s",trace_path)) trace_path="trace.csv";
  if(!$value$plusargs("REGS=%s",regs_path)) regs_path="regs.txt";
  if(!$value$plusargs("REASON=%s",reason_path)) reason_path="reason.txt";
  n=$value$plusargs("DELAY=%d",delay_max);n=$value$plusargs("SEED=%d",seed);
  if($value$plusargs("VCD=%s",vcd_path)) begin $dumpfile(vcd_path);$dumpvars(0,tb_core);end
  $readmemh(image,imem);trace_fd=$fopen(trace_path,"w");
  $fdisplay(trace_fd,"pc,instr,rd,value,mem,store,addr,data");
  repeat(4) @(negedge clk);rst=0;resume=1;
  @(negedge clk);resume=0;
  while(!halted) begin
   @(negedge clk);cycles=cycles+1;
   if(cycles>200000) $fatal(1,"CPU timeout pc=%h",pc);
  end
  $fclose(trace_fd);regs_fd=$fopen(regs_path,"w");
  for(n=0;n<32;n=n+1) begin dbg_addr=n;#1;$fdisplay(regs_fd,"%08x",dbg_data);end
  $fclose(regs_fd);reason_fd=$fopen(reason_path,"w");
  $fdisplay(reason_fd,"%0d %08x %0d %0d",reason,pc,cycles,wait_observed);$fclose(reason_fd);$finish;
 end
 always @(negedge clk) if(rv)
  $fdisplay(trace_fd,"%08x,%08x,%0d,%08x,%0d,%0d,%08x,%08x",rp,ri,rd,rval,rm,rs,ra,rmd);
 always @(posedge clk) begin
  ack<=0;err<=0;
  if(rst) begin pending<=0;served<=0;end
  else if(!cyc || !stb) begin pending<=0;served<=0;end
  else if(!pending && !served) begin
    pending<=1; saved_addr<=addr;saved_data<=wdata;saved_sel<=sel;saved_we<=we;
    countdown<=delay_max==0 ? 0 : ($unsigned($random(seed))%(delay_max+1));
  end else if(pending) begin
    if(addr!==saved_addr || wdata!==saved_data || sel!==saved_sel || we!==saved_we)
      $fatal(1,"request changed while waiting");
    if(countdown!=0) begin countdown<=countdown-1;wait_observed<=wait_observed+1;end
    else begin
      pending<=0;served<=1;
      if(addr[31:14]==0 || addr[31:14]==18'h04000) begin
        ack<=1;rdata<=addr[31:14]==0 ? imem[addr[13:2]] : dmem[addr[13:2]];
        if(we) begin
         for(integer lane=0;lane<4;lane=lane+1) if(sel[lane]) begin
          if(addr[31:14]==0) imem[addr[13:2]][lane*8+:8]<=wdata[lane*8+:8];
          else dmem[addr[13:2]][lane*8+:8]<=wdata[lane*8+:8];
         end
        end
      end else err<=1;
    end
  end
 end
endmodule
