///////////////////////////////////////////
// cam_line.sv
//
// Written: tfleming@hmc.edu & jtorrey@hmc.edu 6 April 2021
// Modified:
//
// Purpose: CAM line for the translation lookaside buffer (TLB)
//          Determines whether a virtual address matches the stored key.
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

module cam_line #(parameter KEY_BITS = 20,
                  parameter HIGH_SEGMENT_BITS = 10) (
  input                 clk, reset,

  // The requested page number to compare against the key
  input  [KEY_BITS-1:0] VirtualPageNumber,

  // Signals to write a new entry to this line
  input                 CAMLineWrite,
  input  [1:0]          PageTypeWrite,

  // Flush this line (set valid to 0)
  input                 TLBFlush,

  // This entry is a key for a giga, mega, or kilopage.
  // PageType == 2'b00 --> kilopage
  // PageType == 2'b01 --> megapage
  // PageType == 2'b11 --> gigapage
  output [1:0]          PageType,  // *** should this be the stored version or the always updated one?
  output                Match
);

  // This entry has KEY_BITS for the key plus one valid bit.
  logic                Valid;
  logic [KEY_BITS-1:0] Key;

  // When determining a match for a superpage, we might use only a portion of
  // the input VirtualPageNumber. Unused parts of the VirtualPageNumber are
  // zeroed in VirtualPageNumberQuery to better match with Key.
  logic [KEY_BITS-1:0] VirtualPageNumberQuery;

  // On a write, update the type of the page referred to by this line.
  flopenr #(2) pagetypeflop(clk, reset, CAMLineWrite, PageTypeWrite, PageType);
  //mux2 #(2) pagetypemux(StoredPageType, PageTypeWrite, CAMLineWrite, PageType);

  // On a write, set the valid bit high and update the stored key.
  // On a flush, zero the valid bit and leave the key unchanged.
  // *** Might we want to update stored key right away to output match on the
  // write cycle? (using a mux)
  flopenrc #(1) validbitflop(clk, reset, TLBFlush, CAMLineWrite, 1'b1, Valid);
  flopenr #(KEY_BITS) keyflop(clk, reset, CAMLineWrite, VirtualPageNumber, Key);

  // Calculate the actual query key based on the input key and the page type.
  // For example, a megapage in sv39 only cares about VPN2 and VPN1, so VPN0
  // should automatically match.
  page_number_mixer #(KEY_BITS, HIGH_SEGMENT_BITS) mixer(VirtualPageNumber, Key, PageType, VirtualPageNumberQuery);

  assign Match = ({1'b1, VirtualPageNumberQuery} == Key);

endmodule