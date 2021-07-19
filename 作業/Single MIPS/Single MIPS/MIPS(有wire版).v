// Single Cycle MIPS
//=========================================================
// Input/Output Signals:
// positive-edge triggered         clk
// active low asynchronous reset   rst_n
// instruction memory interface    IR_addr, IR
// output for testing purposes     RF_writedata  
//=========================================================
// Wire/Reg Specifications:
// control signals             MemToReg, MemRead, MemWrite, 
//                             RegDST, RegWrite, Branch, 
//                             Jump, ALUSrc, ALUOp
// ALU control signals         ALUctrl
// ALU input signals           ALUin1, ALUin2
// ALU output signals          ALUresult, ALUzero
// instruction specifications  r, j, jal, jr, lw, sw, beq
// sign-extended signal        SignExtend
// MUX output signals          MUX_RegDST, MUX_MemToReg, 
//                             MUX_Src, MUX_Branch, MUX_Jump
// registers input signals     Reg_R1, Reg_R2, Reg_W, WriteData 
// registers                   Register
// registers output signals    ReadData1, ReadData2
// data memory contral signals CEN, OEN, WEN
// data memory output signals  ReadDataMem
// program counter/address     PCin, PCnext, JumpAddr, BranchAddr
//=========================================================
//
module SingleCycle_MIPS( 
    clk,
    rst_n,
    IR_addr,
    IR,
    RF_writedata,
    ReadDataMem,
    CEN,
    WEN,
    A,
    ReadData2,
    OEN
);

//==== in/out declaration =================================
    //-------- processor ----------------------------------
    input         clk, rst_n;
    input  [31:0] IR;
    output [31:0] IR_addr, RF_writedata;
    //-------- data memory --------------------------------
    input  [31:0] ReadDataMem;  // read_data from memory
    output        CEN;  // chip_enable, 0 when you read/write data from/to memory
    output        WEN;  // write_enable, 0 when you write data into SRAM & 1 when you read data from SRAM
    output  [6:0] A;  // address
    output [31:0] ReadData2;  // write_data to memory
    output        OEN;  // output_enable, 0

//==== parameter definition ===============================
    parameter r=6'b000000;
    parameter j=6'b000010;
    parameter jal=6'b000011;
    parameter jr=6'b001000;
    parameter lw=6'b100011;
    parameter sw=6'b101011;
    parameter beq=6'b000100;

//==== reg/wire declaration ===============================

//control signal
    reg [1:0] MemToReg;
    reg MemRead;
    reg MemWrite;
    reg [1:0] RegDST;
    reg RegWrite;
    reg Branch;
    reg [1:0] Jump;
    reg ALUSrc;
// ALU
    reg [1:0] ALUOp;
    wire [2:0] ALUctrl;
    wire [31:0] ALUin1;
    wire [31:0] ALUin2;
    reg [31:0] ALUresult;
    reg ALUzero;
// address
    wire [31:0] SignExtend;
// MUX
    reg [4:0] MUX_RegDST;
    reg [31:0] MUX_MemToReg;
    reg [31:0] MUX_Src;
    reg [31:0] MUX_Branch;
    reg [31:0] MUX_Jump;
// input register
    wire [4:0] Reg_R1;
    wire [4:0] Reg_R2;
    wire [4:0] Reg_W;
    wire [31:0] WriteData;
    reg [31:0] Register [31:0];
// output register
    wire [31:0] ReadData1;
// program counter
    reg [31:0] PCin;
    reg [31:0] PCnext;
    reg [31:0] JumpAddr;
    wire [27:0] JumpAddr1;
    wire [31:0] JumpAddr2;
    reg [31:0] BranchAddr;
// other
    reg [4:0] idx;

//==== combinational part =================================

// CPU output
    assign IR_addr=PCin;
    assign RF_writedata=MUX_MemToReg;
    assign CEN=~(MemRead||MemWrite);
    assign WEN=MemRead;
    assign A=ALUresult[8:2];
    assign ReadData2=Register[Reg_R2];
    assign OEN=0;
// register I/O
    assign Reg_R1=IR[25:21];
    assign Reg_R2=IR[20:16];
    assign Reg_W=MUX_RegDST;
    assign WriteData=MUX_MemToReg;
    assign ReadData1=Register[Reg_R1];
//control unit
always@(*) begin
    case(IR[31:26])
        r:begin//R-format or jr
	    if(IR[5:0]==jr) begin
		MemRead=0;
		MemWrite=0;
		RegWrite=0;
		Jump=2'b10;
	    end
	    else begin
	        MemToReg=2'b00;
	        MemRead=0;
	        MemWrite=0;
	        RegDST=1;
	        RegWrite=1;
	        Branch=0;
	        Jump=2'b00;
	        ALUSrc=0;
	        ALUOp=2'b10;
	    end
	  end
        lw:begin
	    MemToReg=2'b01;
	    MemRead=1;
	    MemWrite=0;
	    RegDST=0;
	    RegWrite=1;
	    Branch=0;
	    Jump=2'b00;
	    ALUSrc=1;
	    ALUOp=2'b00;
	  end
        sw:begin
	    MemRead=0;
	    MemWrite=1;
	    RegWrite=0;
	    Branch=0;
	    Jump=2'b00;
	    ALUSrc=1;
	    ALUOp=2'b00;
	  end
        beq:begin
	    MemRead=0;
	    MemWrite=0;
	    RegWrite=0;
	    Branch=1;
	    Jump=2'b00;
	    ALUSrc=0;
	    ALUOp=2'b01;
	  end
        j:begin
	    MemRead=0;
	    MemWrite=0;
	    RegWrite=0;
	    Jump=2'b01;
	  end
	jal:begin
	    MemToReg=2'b10;
	    MemRead=0;
	    MemWrite=0;
	    RegDST=2'b10;
	    RegWrite=1;
	    Jump=2'b01;
	  end
	default:begin
	    MemToReg=2'b00;
	    MemRead=0;
	    MemWrite=0;
	    RegDST=2'b00;
	    RegWrite=0;
	    Branch=0;
	    Jump=2'b00;
	    ALUSrc=0;
	    ALUOp=2'b00;
	  end
    endcase
end
// alu control
    assign ALUctrl[2]=ALUOp[0]|(ALUOp[1]&IR[1]);
    assign ALUctrl[1]=(~ALUOp[1])|(~IR[2]);
    assign ALUctrl[0]=ALUOp[1]&(IR[3]|IR[0]);
// alu
    assign ALUin1=Register[Reg_R1];
    assign ALUin2=MUX_Src;
always @(*) begin
    case(ALUctrl)
	3'b000:begin
	    ALUresult=ALUin1&ALUin2;
            ALUzero=0;
	       end
        3'b001:begin
	    ALUresult=ALUin1|ALUin2;
	    ALUzero=0;
	       end
	3'b010:begin
	    ALUresult=ALUin1+ALUin2;
	    ALUzero=0;
	       end
	3'b110:begin
	    ALUresult=ALUin1-ALUin2;
	    ALUzero=0;
	       end
	3'b111:begin
	    ALUresult=(ALUin1<ALUin2)? 1:0;
	    ALUzero=(ALUin1==ALUin2)? 1:0;
	       end
	default:begin
	    ALUresult=0;
	    ALUzero=0;
	       end
    endcase
end
// pc
    assign JumpAddr1=IR[25:0]<<2;
    assign JumpAddr2=PCin+4;
always @(*) begin
    PCnext=MUX_Jump;
    JumpAddr={JumpAddr2[31:28],JumpAddr1};
    BranchAddr=PCin+4+SignExtend<<2;
end
// sign extemsion
    assign SignExtend={{16{IR[15]}},IR[15:0]};
// MUX
always @(*) begin
    if(RegDST==2'b00)
	MUX_RegDST=IR[20:16];
    else if(RegDST==2'b01)
	MUX_RegDST=IR[15:11];
    else if(RegDST==2'b10)
	MUX_RegDST=5'b11111;

    if(MemToReg==2'b00)
	MUX_MemToReg=ALUresult;
    else if(MemToReg==2'b01)
	MUX_MemToReg=ReadDataMem;
    else if(MemToReg==2'b10)
	MUX_MemToReg=PCin+4;

    MUX_Branch=(Branch&ALUzero)? BranchAddr:PCin+4;

    if(Jump==2'b00)
	MUX_Jump=MUX_Branch;
    else if(Jump==2'b01)
	MUX_Jump=JumpAddr;
    else if(Jump==2'b10)
	MUX_Jump=Register[Reg_R1];

    MUX_Src=ALUSrc? SignExtend:Register[Reg_R2];
end
//==== sequential part ====================================
    always@(posedge clk or negedge rst_n) begin
	if(rst_n==0) begin
	    PCin<=0;
	    for(idx=0;idx<32;idx=idx+1)begin
	        Register[idx]<=0;
	    end
	end
	else begin
	    PCin <= PCnext;
	    if(RegWrite==1'b1&&Reg_W!=0)
	        Register[Reg_W] <= WriteData;
	end
    end
//=========================================================
endmodule
