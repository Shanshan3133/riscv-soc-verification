module regfile (
    input logic clk,
    input logic rst,
    input logic we,
    input logic [4:0] waddr,
    input logic [31:0] wdata,
    input logic [4:0] raddr1, raddr2,
    output logic [31:0] rdata1, rdata2
);
    logic [31:0] regs [1:31];
    integer i;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 1; i < 32; i = i + 1) regs[i] <= 32'b0;
        end else if (we && waddr != 0) begin
            regs[waddr] <= wdata;
        end
    end
    // Writes become visible after the clock edge; no combinational bypass.
    assign rdata1 = (raddr1 == 0) ? 32'b0 : regs[raddr1];
    assign rdata2 = (raddr2 == 0) ? 32'b0 : regs[raddr2];
endmodule
