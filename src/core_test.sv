`timescale 1ns / 1ps

module core_test();

parameter DataWidth=32;
parameter AddrWidth=15;

    logic  clock;
    logic  reset;
    logic  [DataWidth-1:0]Reg_Out;
    
buraq_top_rv32im core(

    .brq_clk(clock),
    .brq_rst(reset),
    //OUTPUT//
    .Reg_Out(Reg_Out)
  );


initial begin
clock=0;
reset=1;
#2;
reset=0;
end

    always begin
        #1 clock = ~clock;  // timescale is 1ns so #5 provides 100MHz clock
    end

endmodule:core_test
