`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2017/11/02 15:12:22
// Design Name:
// Module Name: datapath
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module datapath(
           input wire clk,rst,
           //fetch stage
           output wire[31:0] pcF,
           input wire[31:0] instrF,
           //decode stage
           input wire pcsrcD,branchD,
           input wire jumpD,
           output wire equalD,
           output wire[5:0] opD,functD,
           input wire[3:0] memwriteD,
           //execute stage
           input wire memtoregE,
           input wire alusrcE,regdstE,
           input wire regwriteE,
           input wire[7:0] alucontrolE,
           output wire flushE,
           //mem stage
           input wire memtoregM,
           input wire regwriteM,
           output wire[31:0] aluoutM,writedataM,
           input wire[31:0] readdataM,
           input wire[2:0] lshbM,
           output wire[3:0] memwriteM,
           //writeback stage
           input wire memtoregW,
           input wire regwriteW,
           input wire[2:0] lshbW
       );

//fetch stage
wire stallF;
//FD
wire [31:0] pcnextFD,pcnextbrFD,pcplus4F,pcbranchD;
//decode stage
wire [31:0] pcplus4D,instrD;
wire forwardaD,forwardbD;
wire [4:0] rsD,rtD,rdD;
wire flushD,stallD;
wire [31:0] signimmD,signimmshD;
wire [31:0] srcaD,srca2D,srcbD,srcb2D;
//execute stage
wire [1:0] forwardaE,forwardbE;
wire [4:0] rsE,rtE,rdE;
wire [4:0] writeregE;
wire [31:0] signimmE;
wire [31:0] srcaE,srca2E,srcbE,srcb2E,srcb3E;
wire [31:0] aluoutE;
wire [3:0] memwriteE;
//mem stage
wire [4:0] writeregM;
wire [3:0] memwriteM1;
//writeback stage
wire [4:0] writeregW;
wire [31:0] aluoutW,readdataW,resultW;
wire [31:0] readdataWB;//鍐欏洖瀛楋拷?锟藉崐瀛楋拷?锟藉瓧鑺傛嫇锟???

//hazard detection
hazard h(
           //fetch stage
           stallF,
           //decode stage
           rsD,rtD,
           branchD,
           forwardaD,forwardbD,
           stallD,
           //execute stage
           rsE,rtE,
           writeregE,
           regwriteE,
           memtoregE,
           forwardaE,forwardbE,
           flushE,
           //mem stage
           writeregM,
           regwriteM,
           memtoregM,
           //write back stage
           writeregW,
           regwriteW
       );

//next PC logic (operates in fetch an decode)
mux2 #(32) pcbrmux(pcplus4F,pcbranchD,pcsrcD,pcnextbrFD);
mux2 #(32) pcmux(pcnextbrFD,
                 {pcplus4D[31:28],instrD[25:0],2'b00},
                 jumpD,pcnextFD);

//regfile (operates in decode and writeback)
regfile rf(clk,regwriteW,rsD,rtD,writeregW,resultW,srcaD,srcbD);

//fetch stage logic
pc #(32) pcreg(clk,rst,~stallF,pcnextFD,pcF);
adder pcadd1(pcF,32'b100,pcplus4F);
//decode stage
flopenr #(32) r1D(clk,rst,~stallD,pcplus4F,pcplus4D);
flopenrc #(32) r2D(clk,rst,~stallD,flushD,instrF,instrD);
signext se(instrD[15:0],signimmD);
sl2 immsh(signimmD,signimmshD);
adder pcadd2(pcplus4D,signimmshD,pcbranchD);
mux2 #(32) forwardamux(srcaD,aluoutM,forwardaD,srca2D);
mux2 #(32) forwardbmux(srcbD,aluoutM,forwardbD,srcb2D);
eqcmp comp(srca2D,srcb2D,equalD);

assign opD = instrD[31:26];
assign functD = instrD[5:0];
assign rsD = instrD[25:21];
assign rtD = instrD[20:16];
assign rdD = instrD[15:11];

//execute stage
floprc #(32) r1E(clk,rst,flushE,srcaD,srcaE);
floprc #(32) r2E(clk,rst,flushE,srcbD,srcbE);
floprc #(32) r3E(clk,rst,flushE,signimmD,signimmE);
floprc #(5) r4E(clk,rst,flushE,rsD,rsE);
floprc #(5) r5E(clk,rst,flushE,rtD,rtE);
floprc #(5) r6E(clk,rst,flushE,rdD,rdE);
floprc #(4) r7E(clk,rst,flushE,memwriteD,memwriteE);

mux3 #(32) forwardaemux(srcaE,resultW,aluoutM,forwardaE,srca2E);
mux3 #(32) forwardbemux(srcbE,resultW,aluoutM,forwardbE,srcb2E);
mux2 #(32) srcbmux(srcb2E,signimmE,alusrcE,srcb3E);
alu alu(srca2E,srcb3E,alucontrolE,aluoutE);
mux2 #(5) wrmux(rtE,rdE,regdstE,writeregE);

//mem stage
flopr #(32) r1M(clk,rst,srcb2E,writedataM);
flopr #(32) r2M(clk,rst,aluoutE,aluoutM);
flopr #(5) r3M(clk,rst,writeregE,writeregM);
flopr #(4) r4M(clk,rst,memwriteE,memwriteM1);
//temp memwrite
reg[3:0] memwriteTemp = 4'b0000;
assign memwriteM = memwriteTemp;
always @(*)
begin
    case(lshbM)
        //sw
        3'b111:
        begin
            memwriteTemp <= 4'b1111;
        end
        //sh
        3'b110:
        begin
            case(aluoutM[1])
                1'b0:
                    memwriteTemp <= 4'b1100;
                1'b1:
                    memwriteTemp <= 4'b0011;
                default:
                    memwriteTemp <= 4'b0000;
            endcase
        end
        //sb
        3'b101:
        begin
            case(aluoutM[1:0])
                2'b00:
                    memwriteTemp <= 4'b1000;
                2'b01:
                    memwriteTemp <= 4'b0100;
                2'b10:
                    memwriteTemp <= 4'b0010;
                2'b11:
                    memwriteTemp <= 4'b0001;
                default:
                    memwriteTemp <= 4'b0000;
            endcase
        end
        default:
        begin
            memwriteTemp <= 4'b0000;
        end
    endcase
end

//assign memwriteM =memwriteM1;
//writeback stage
flopr #(32) r1W(clk,rst,aluoutM,aluoutW);
flopr #(32) r2W(clk,rst,readdataM,readdataW);
flopr #(5) r3W(clk,rst,writeregM,writeregW);
assign readdataWB = (lshbW==3'b000)?{{24{readdataW[31]}},readdataW[31:24]}:(lshbW==3'b001)?{{24{1'b0}},readdataW[31:24]}:(lshbW==3'b010)?{{16{readdataW[31]}},readdataW[31:16]}:(lshbW==3'b011)?{{16{1'b0}},readdataW[31:16]}:readdataW;
//assign readdataWB = readdataW;
mux2 #(32) resmux(aluoutW,readdataWB,memtoregW,resultW);
endmodule
