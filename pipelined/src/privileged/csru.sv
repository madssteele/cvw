///////////////////////////////////////////
// csru.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified: 
//
// Purpose: User-Mode Control and Status Registers for Floating Point
// 
// Documentation: RISC-V System on Chip Design Chapter 5
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module csru #(parameter 
  FFLAGS = 12'h001,
  FRM = 12'h002,
  FCSR = 12'h003) (
    input  logic             clk, reset, 
    input  logic             InstrValidNotFlushedM,
    input  logic             CSRUWriteM,
    input  logic [11:0]      CSRAdrM,
    input  logic [`XLEN-1:0] CSRWriteValM,
    input  logic [1:0]       STATUS_FS,
    output logic [`XLEN-1:0] CSRUReadValM,  
    input  logic [4:0]       SetFflagsM,
    output logic [2:0]       FRM_REGW,
    output logic             WriteFRMM, WriteFFLAGSM,
    output logic             IllegalCSRUAccessM
  );

  // Floating Point CSRs in User Mode only needed if Floating Point is supported
  if (`F_SUPPORTED | `D_SUPPORTED) begin:csru
    logic [4:0] FFLAGS_REGW;
    logic [2:0] NextFRMM;
    logic [4:0] NextFFLAGSM;
      
    // Write enables
    //assign WriteFCSRM = CSRUWriteM & (CSRAdrM == FCSR)  & InstrValidNotFlushedM;
    assign WriteFRMM = (CSRUWriteM & (STATUS_FS != 2'b00) & (CSRAdrM == FRM | CSRAdrM == FCSR))  & InstrValidNotFlushedM;
    assign WriteFFLAGSM = (CSRUWriteM & (STATUS_FS != 2'b00) & (CSRAdrM == FFLAGS | CSRAdrM == FCSR))  & InstrValidNotFlushedM;
  
    // Write Values
    assign NextFRMM = (CSRAdrM == FCSR) ? CSRWriteValM[7:5] : CSRWriteValM[2:0];
    assign NextFFLAGSM = WriteFFLAGSM ? CSRWriteValM[4:0] : FFLAGS_REGW | SetFflagsM;

    // CSRs
    flopenr #(3) FRMreg(clk, reset, WriteFRMM, NextFRMM, FRM_REGW);
    flopr   #(5) FFLAGSreg(clk, reset, NextFFLAGSM, FFLAGS_REGW); 

    // CSR Reads
    always_comb begin
      if (STATUS_FS == 2'b00) begin // fpu disabled, trap
        IllegalCSRUAccessM = 1;
        CSRUReadValM = 0;
      end else begin
        IllegalCSRUAccessM = 0;
        case (CSRAdrM) 
          FFLAGS:    CSRUReadValM = {{(`XLEN-5){1'b0}}, FFLAGS_REGW};
          FRM:       CSRUReadValM = {{(`XLEN-3){1'b0}}, FRM_REGW};
          FCSR:      CSRUReadValM = {{(`XLEN-8){1'b0}}, FRM_REGW, FFLAGS_REGW};
          default: begin
                      CSRUReadValM = 0; 
                      IllegalCSRUAccessM = 1;
          end         
        endcase
      end
    end
  end else begin // if not supported
    assign FRM_REGW = 0;
    assign CSRUReadValM = 0;
    assign IllegalCSRUAccessM = 1;
  end
endmodule
