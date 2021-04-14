// *****************************************************************************
// Filename    : seriallnterface.v
// Create on   : 2021/3/17 14:39
// Revise on   : 2021/3/17 14:39
// Version     : 1.0
// Author      : ccb
// Email       : 
// Description : i2c slave���룬����ӻ��Ľ��պͷ�������
//               i2c master wr: devAddr+w, regAddr, dataLen, data[regAddr], ...data[regAddr+dataLen]
//               i2c master rd: devAddr+w, regAddr, dataLen, devAddr+r, data[regAddr], ...data[regAddr+dataLen]
//               ֧�ֵ��ֽڻ��߶��ֽ����ݵĶ�ȡ�뷢�ͣ��û������Զ������üĴ���
// Editor      : sublime text 3, tab size 4
// *****************************************************************************

`include "i2cSlave_define.v"

module serialInterface (clearStartStopDet, clk, dataIn, dataOut, regAddr, rst, scl, sdaIn, sdaOut, startStopDetState, writeEn, data_length, txlen_flag);
input           clk;
//input   [7:0]dataIn;
input   [15:0]  dataIn;
input           rst; 
input           scl;
input           sdaIn;
input   [1:0]   startStopDetState;
output          clearStartStopDet;
output  [7:0]   dataOut;
output  [7:0]   regAddr;
output          sdaOut;
output          writeEn;
output  [7:0]   data_length;

input           txlen_flag;

reg             clearStartStopDet, next_clearStartStopDet;
wire            clk;
// wire    [7:0]dataIn;
reg [7:0]       dataOut, next_dataOut;
reg [7:0]       regAddr, next_regAddr;
wire            rst;
wire            scl;
wire            sdaIn;
reg             sdaOut, next_sdaOut;
wire    [1:0]   startStopDetState;
reg             writeEn, next_writeEn;

// diagram signals declarations
reg [2:0]       bitCnt, next_bitCnt;
reg [7:0]       rxData, next_rxData;
reg [1:0]       streamSt, next_streamSt;
reg [7:0]       txData, next_txData;

reg             tx_flag, next_tx_flag;
reg             reg_flag, next_reg_flag;
reg [7:0]       dataIn_lsb, next_dataIn_lsb;
reg [7:0]       data_length, next_data_length;
// BINARY ENCODED state machine: SISt
// State codes definitions:
`define START 4'b0000
`define CHK_RD_WR 4'b0001
`define READ_RD_LOOP 4'b0010
`define READ_WT_HI 4'b0011
`define READ_CHK_LOOP_FIN 4'b0100
`define READ_WT_LO 4'b0101
`define READ_WT_ACK 4'b0110
`define WRITE_WT_LO 4'b0111
`define WRITE_WT_HI 4'b1000
`define WRITE_CHK_LOOP_FIN 4'b1001
`define WRITE_LOOP_WT_LO 4'b1010
`define WRITE_ST_LOOP 4'b1011
`define WRITE_WT_LO2 4'b1100
`define WRITE_WT_HI2 4'b1101
`define WRITE_CLR_WR 4'b1110
`define WRITE_CLR_ST_STOP 4'b1111

reg [3:0]   CurrState_SISt, NextState_SISt;

// Diagram actions (continuous assignments allowed only: assign ...)
// diagram ACTION


// Machine: SISt

// NextState logic (combinatorial)
always @ (startStopDetState or streamSt or scl or txData or bitCnt or rxData or sdaIn or regAddr or dataIn or sdaOut 
          or writeEn or dataOut or clearStartStopDet or CurrState_SISt or tx_flag or reg_flag or dataIn_lsb or data_length or txlen_flag)
begin
    NextState_SISt         <= CurrState_SISt;
    // Set default values for outputs and signals
    next_streamSt          <= streamSt;
    next_txData            <= txData;
    next_rxData            <= rxData;
    next_sdaOut            <= sdaOut;
    next_writeEn           <= writeEn;
    next_dataOut           <= dataOut;
    next_bitCnt            <= bitCnt;
    next_clearStartStopDet <= clearStartStopDet;
    next_regAddr           <= regAddr;
    next_tx_flag           <= tx_flag;
    next_reg_flag          <= reg_flag;
    next_dataIn_lsb        <= dataIn_lsb;
    next_data_length       <= data_length;
    case (CurrState_SISt)  // synopsys parallel_case full_case
    `START:
    begin
        next_streamSt          <= `STREAM_IDLE;
        next_txData            <= 8'h00;
        next_rxData            <= 8'h00;
        next_sdaOut            <= 1'b1;
        next_writeEn           <= 1'b0;
        next_dataOut           <= 8'h00;
        next_bitCnt            <= 3'b000;
        next_clearStartStopDet <= 1'b0;
        NextState_SISt         <= `CHK_RD_WR;

        next_tx_flag           <= 1'b1;
        next_reg_flag          <= 1'b0;
        next_dataIn_lsb        <= 8'd0;
        next_data_length       <= 8'd0;

    end
    `CHK_RD_WR:
    begin
        if (streamSt == `STREAM_READ)
        begin
            NextState_SISt  <= `READ_RD_LOOP;
            if(txlen_flag == 1'b1) begin
                if(tx_flag == 1'b1) begin  //�ȷ��͸��ֽڣ��ڷ��͵��ֽ�
                    next_txData     <= dataIn[15:8];
                    next_tx_flag    <= 1'd0;
                    next_dataIn_lsb <= dataIn[7:0];
                end
                else begin
                    next_tx_flag    <= tx_flag;                
                    next_txData     <= dataIn_lsb;
                end
            end
            else begin
                next_txData         <= dataIn[7:0];
            end
        
            //next_regAddr <= regAddr + 1'b1;
            //next_regAddr   <= regAddr; //��ַ���ֲ���
            next_bitCnt    <= 3'b001;
        end
        else
        begin
            NextState_SISt <= `WRITE_WT_HI;
            next_rxData    <= 8'h00;
        end
    end
    /////////////////////////////////////////////
    `READ_RD_LOOP:
    begin
        if (scl == 1'b0) //scl�͵�ƽ��������
        begin
            NextState_SISt <= `READ_WT_HI;
            next_sdaOut    <= txData [7];
            next_txData    <= {txData [6:0], 1'b0};
        end
    end
    `READ_WT_HI:
    begin
        if (scl == 1'b1) //scl�ߵ�ƽ���������������ݣ��ӻ�������һλ�Ĵ���
        begin
            NextState_SISt <= `READ_CHK_LOOP_FIN;
        end
    end
    `READ_CHK_LOOP_FIN:
    begin
        if (bitCnt == 3'b000)
        begin
            NextState_SISt <= `READ_WT_LO;
        end
        else
        begin
            NextState_SISt <= `READ_RD_LOOP;
            next_bitCnt <= bitCnt + 1'b1;
        end
    end
    `READ_WT_LO:
    begin
        if (scl == 1'b0) //8λ���ݷ�����ɺ�scl�͵�ƽʱ�ͷ����ߣ�sda���1
        begin
            NextState_SISt <= `READ_WT_ACK;
            next_sdaOut    <= 1'b1;
        end
    end
    `READ_WT_ACK:
    begin
        if (scl == 1'b1) //��scl�ĸߵ�ƽ��ȡ������Ӧ���źţ�1������Ӧ��0����Ӧ��
        begin
            NextState_SISt    <= `CHK_RD_WR;
            if (sdaIn == `I2C_NAK)
                next_streamSt <= `STREAM_IDLE;
        end
    end
    ///////////////////////////////////////////////
    `WRITE_WT_LO:
    begin
        if ((scl == 1'b0) && (startStopDetState == `STOP_DET || 
        (streamSt == `STREAM_IDLE && startStopDetState == `NULL_DET)))
        begin

            NextState_SISt    <= `WRITE_CLR_ST_STOP;
            case (startStopDetState) //startStopDetStateд�豸��ַ�Ĺ�����Ϊ1���Ĵ���������Ϊ0��ֹͣ�ź���2
            `NULL_DET:
                next_bitCnt   <= bitCnt + 1'b1;
            `START_DET: begin
                next_streamSt <= `STREAM_IDLE;
                next_rxData   <= 8'h00;
            end
            default: ;
            endcase
                next_streamSt <= `STREAM_IDLE;
                next_clearStartStopDet <= 1'b1;
        end
        else if (scl == 1'b0)
        begin
            NextState_SISt    <= `WRITE_ST_LOOP;
            case (startStopDetState)
            `NULL_DET:
                next_bitCnt   <= bitCnt + 1'b1;
            `START_DET: begin
                next_streamSt <= `STREAM_IDLE;
                next_rxData   <= 8'h00;
            end
            default: ;
            endcase
        end
    end
    `WRITE_WT_HI:
    begin
        if (scl == 1'b1) //�ӻ���scl�ߵ�ƽ������һλsda����
        begin
            NextState_SISt <= `WRITE_WT_LO;
            next_rxData    <= {rxData [6:0], sdaIn};
            next_bitCnt    <= 3'b000;
        end
    end
    `WRITE_CHK_LOOP_FIN:
    begin
        if (bitCnt == 3'b111)
        begin
            NextState_SISt <= `WRITE_CLR_WR;
            next_sdaOut    <= `I2C_ACK;
            case (streamSt)
            `STREAM_IDLE: begin
                if (rxData[7:1] == `I2C_ADDRESS && startStopDetState == `START_DET) 
                begin //`START_DET����д�豸��ַ�׶�
                    if (rxData[0] == 1'b1)
                    next_streamSt <= `STREAM_READ;//���������ӻ�д
                    else
                    next_streamSt <= `STREAM_WRITE_ADDR;//����д���ӻ���
                end
                else
                    next_sdaOut   <= `I2C_NAK;
                end
            `STREAM_WRITE_ADDR: begin
                next_streamSt     <= `STREAM_WRITE_DATA;
                next_regAddr      <= rxData;//�Ĵ�����ַ

                next_reg_flag     <= 1'b1;
            end
            `STREAM_WRITE_DATA: begin
                //next_dataOut <= rxData;
                //next_writeEn <= 1'b1;
                if(reg_flag == 1'b1) begin
                    next_reg_flag     <= 1'b0;
                    next_writeEn      <= 1'b0;
                    next_data_length  <= rxData;//��һ�����ݴ������ݳ���
                end
                else begin
                    next_reg_flag     <= reg_flag;
                    next_writeEn      <= 1'b1; //ֻ��д�ڶ������ݵ�ʱ���������������
                    next_dataOut      <= rxData;//�ڶ������յ����ݲ�������������
                end
            end
            default:
                next_streamSt <= streamSt;
            endcase
        end
        else
        begin
            NextState_SISt <= `WRITE_ST_LOOP;
            next_bitCnt    <= bitCnt + 1'b1;
        end
    end
    `WRITE_LOOP_WT_LO:
    begin
        if (scl == 1'b0)
        begin
            NextState_SISt <= `WRITE_CHK_LOOP_FIN;
        end
    end
    `WRITE_ST_LOOP:
    begin
        if (scl == 1'b1)
        begin
            NextState_SISt <= `WRITE_LOOP_WT_LO;
            next_rxData    <= {rxData [6:0], sdaIn};
        end
    end
    `WRITE_WT_LO2:
    begin
        if (scl == 1'b0)
        begin
            NextState_SISt     <= `CHK_RD_WR;
            next_sdaOut        <= 1'b1;
        end
    end
    `WRITE_WT_HI2:
    begin
        next_clearStartStopDet <= 1'b0;
        if (scl == 1'b1)
        begin
            NextState_SISt     <= `WRITE_WT_LO2;
        end
    end
    `WRITE_CLR_WR:
    begin
        if (writeEn == 1'b1)//1һ������д��ʱ
        //next_regAddr             <= regAddr + 1'b1;
        //next_regAddr             <= regAddr;
            next_writeEn           <= 1'b0;
            next_clearStartStopDet <= 1'b1;
            NextState_SISt         <= `WRITE_WT_HI2;
    end
    `WRITE_CLR_ST_STOP:
    begin
        next_clearStartStopDet     <= 1'b0;
        NextState_SISt             <= `CHK_RD_WR;
    end
    endcase
end

// Current State Logic (sequential)
always @ (posedge clk)
begin
    if (rst == 1'b1)
        CurrState_SISt <= `START;
    else
        CurrState_SISt <= NextState_SISt;
end

// Registered outputs logic
always @ (posedge clk)
begin
    if (rst == 1'b1)
    begin
        sdaOut            <= 1'b1;
        writeEn           <= 1'b0;
        dataOut           <= 8'h00;
        clearStartStopDet <= 1'b0;
        // regAddr        <=     // Initialization in the reset state or default value required!!
        streamSt          <= `STREAM_IDLE;
        txData            <= 8'h00;
        rxData            <= 8'h00;
        bitCnt            <= 3'b000;

        tx_flag           <= 1'b1;
        reg_flag          <= 1'b0;
        dataIn_lsb        <= 8'd0;
        data_length       <= 8'd0;
    end
    else 
    begin
        sdaOut            <= next_sdaOut;
        writeEn           <= next_writeEn;
        dataOut           <= next_dataOut;
        clearStartStopDet <= next_clearStartStopDet;
        regAddr           <= next_regAddr;
        streamSt          <= next_streamSt;
        txData            <= next_txData;
        rxData            <= next_rxData;
        bitCnt            <= next_bitCnt;

        tx_flag           <= next_tx_flag;
        reg_flag          <= next_reg_flag;
        dataIn_lsb        <= next_dataIn_lsb;
        data_length       <= next_data_length;
    end
end

endmodule