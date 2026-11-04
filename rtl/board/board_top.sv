// Artix-7 MMCM: 100 MHz input -> 1 GHz VCO -> 10 MHz SoC clock.
module board_top(
 input wire clk100,reset_button,debug_rx,uart_rx,
 output wire debug_tx,uart_tx,
 input wire [3:0] switches, output wire [3:0] leds,output wire [5:0] observe
);
 wire clk_in,clk_fb_raw,clk_fb,clk_soc_raw,clk_soc,locked;
 IBUF clock_input(.I(clk100),.O(clk_in));
 MMCME2_BASE #(.CLKIN1_PERIOD(10.0),.CLKFBOUT_MULT_F(10.0),.DIVCLK_DIVIDE(1),
  .CLKOUT0_DIVIDE_F(100.0),.STARTUP_WAIT("FALSE")) clock_manager(
  .CLKIN1(clk_in),.CLKFBIN(clk_fb),.CLKFBOUT(clk_fb_raw),.CLKFBOUTB(),
  .CLKOUT0(clk_soc_raw),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),
  .CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6(),.LOCKED(locked),
  .PWRDWN(1'b0),.RST(reset_button));
 BUFG feedback_buffer(.I(clk_fb_raw),.O(clk_fb));
 BUFG soc_clock_buffer(.I(clk_soc_raw),.O(clk_soc));
 fpga_top #(.UART_DIV(87)) system(.clk100(clk_soc),.reset_button(reset_button|!locked),
  .debug_rx,.uart_rx,.debug_tx,.uart_tx,.switches,.leds,.observe);
endmodule
