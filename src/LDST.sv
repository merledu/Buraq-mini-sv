`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MERL-UIT
// Engineer: 
// 
// Create Date: 01/04/2020 06:05:18 PM
// Design Name: Buraq-mini-RV32IM
// Module Name: LDST
// Project Name: BURAQ
// Target Devices: Arty A7 35T
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision: 
// Revision 0.02 - Added misaligned access and lbu,lhu instructions
// Additional Comments: Added aditional output "ldst_stall" to perform sb,sh in multi cycles
// 
//////////////////////////////////////////////////////////////////////////////////

module LDST#(
parameter DataWidth = 32,
parameter RegAddrWidth = 5,
parameter AddrWidth = 15
)
(
    input brq_clk,
    input brq_rst,
    input stall,
    input ieu_regfile_en,
    input [2:0]ieu_func3,
    input [1:0]ldst_check_stall,
    input [DataWidth-1:0]ieu_alu_result,
    input [DataWidth-1:0]ldst_load_data_in,
    input [DataWidth-1:0]ieu_mem_addr,
    input [DataWidth-1:0]ieu_store_data,
    input [RegAddrWidth-1:0]ieu_addr_dst,
    input ieu_memtoreg,
    
    output logic ldst_regfile_en,
    output logic ldst_resume,wb_resume,
    output logic [2:0]byte_en,
    output logic [AddrWidth-1:0]ldst_mem_addr,
    output logic [DataWidth-1:0]ldst_alu_result,
    output logic [DataWidth-1:0]ldst_store_data,
    output logic [DataWidth-1:0]ldst_load_data,
    output logic [RegAddrWidth-1:0]ldst_addr_dst,
    output logic ldst_memtoreg,
    output logic ldst_stall
 );
logic mem_busy;
logic [1:0]wb_check_stall;
logic [1:0]byte_sel;
logic [AddrWidth-1:0]address;
logic [DataWidth-1:0]load_data;
logic [7:0]storing_byte;
logic [15:0]storing_half_byte;
logic [DataWidth-1:0]wdata;
logic [DataWidth-1:0]modified_wdata;
logic unsigned_acces;

assign ldst_store_data = (ieu_func3 == 3'b010) ? ieu_store_data : {modified_wdata | ldst_load_data_in};
assign storing_byte = ldst_store_data[7:0];
assign storing_half_byte = ldst_store_data[15:0];
assign byte_sel = ieu_mem_addr[1:0];
assign address = ieu_mem_addr>>2;
assign ldst_mem_addr = address[AddrWidth-1:0];

always_comb begin
   if (ieu_func3 == 3'b000)begin //lb | sb
	unsigned_acces = 1'b0;
          if (byte_sel == 2'b00)
               byte_en = 3'b000;
     else if (byte_sel == 2'b01)
               byte_en = 3'b001; 
     else if (byte_sel == 2'b10)
               byte_en = 3'b010; 
     else if (byte_sel == 2'b11)
               byte_en = 3'b011;
   end 
   else if (ieu_func3 == 3'b100)begin //lbu
	unsigned_acces = 1'b1;
          if (byte_sel == 2'b00)
               byte_en = 3'b000;
     else if (byte_sel == 2'b01)
               byte_en = 3'b001; 
     else if (byte_sel == 2'b10)
               byte_en = 3'b010; 
     else if (byte_sel == 2'b11)
               byte_en = 3'b011;
   end 
   else if (ieu_func3 == 3'b001)begin //lh | sh
          if (byte_sel == 2'b0)
               byte_en = 3'b100; 
     else if (byte_sel == 2'b01)
               byte_en = 3'b101;    
   end
   else if (ieu_func3 == 3'b101)begin //lhu
	unsigned_acces = 1'b1;
          if (byte_sel == 2'b0)
               byte_en = 3'b100; 
     else if (byte_sel == 2'b01)
               byte_en = 3'b101;    
   end
   else if (ieu_func3 == 3'b010)begin //lw | sw
          byte_en = 3'b110;
   end
end

////////////misaligned access///////////
// If sb,sh instruction is trap we have to perform
// "read modify write" operation which multi-cycles
// to perform this operation, during this process 
// ldst_stall will remain high to stall the core.
// *Remember only for sb and sh* 
///////////////////////////////////////

always_comb begin 
	modified_wdata = 'b0;
     if (byte_en == 3'b011)  //sb
          modified_wdata[31:24] <= storing_byte;
else if (byte_en == 3'b010)
          modified_wdata[23:16] <= storing_byte;
else if (byte_en == 3'b001)
          modified_wdata[15:8] <= storing_byte;
else if (byte_en == 3'b000)
          modified_wdata[7:0] <= storing_byte;
else if (byte_en == 3'b100)  //sh
          modified_wdata[31:16] <= storing_half_byte;
else if (byte_en == 3'b101)
          modified_wdata[15:0] <= storing_half_byte;
end

///end misaligned access//

always_comb begin
	if (byte_en ==3'b000)   								//lb//
		load_data = unsigned_acces ? {{24{wdata[7]}},wdata[7:0]} : {24'b0,wdata[7:0]};   
   else if (byte_en ==3'b001)
                load_data = unsigned_acces ? {{24{wdata[15]}},wdata[15:8]} : {24'b0,wdata[15:8]};
   else if (byte_en ==3'b010)
                load_data = unsigned_acces ? {{24{wdata[23]}},wdata[23:16]} : {24'b0,wdata[23:16]};
   else if (byte_en ==3'b011)
                load_data = unsigned_acces ? {{24{wdata[31]}},wdata[31:24]} : {24'b0,wdata[31:24]};
   else if (byte_en ==3'b100)   								//lh//
                load_data = unsigned_acces ? {{16{wdata[15]}},wdata[15:8]} : {16'b0,wdata[15:8]};  
   else if (byte_en ==3'b101)
                load_data = unsigned_acces ? {{16{wdata[31]}},wdata[31:16]} : {16'b0,wdata[31:16]}; 
   else if (byte_en ==3'b110)
                load_data = wdata;  						//lw//
end

assign wb_resume   = (wb_check_stall[1])   ? 1'b1 : 1'b0;
assign ldst_resume = (ldst_check_stall[0]) ? 1'b1 : 1'b0;
assign wdata       = ldst_load_data_in;

always @ (posedge brq_clk)begin
    if (brq_rst)begin
        ldst_alu_result <= 32'd0;
        ldst_addr_dst   <= 5'd0;
        ldst_memtoreg   <= 1'b0;
        ldst_regfile_en <= 1'b0; 
        ldst_load_data  <= 32'd0; 
        wb_check_stall  <= 2'b0;   
    end
    else begin
        wb_check_stall  <= ldst_check_stall;
        ldst_load_data  <= load_data;
        ldst_alu_result <= ieu_alu_result;
        ldst_addr_dst   <= ieu_addr_dst;
        ldst_memtoreg   <= ieu_memtoreg;
        ldst_regfile_en <= ieu_regfile_en;
    end
end
endmodule: LDST
