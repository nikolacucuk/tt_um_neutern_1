/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example #(
    parameter NUM_TILES = 8 + 10 + 8 // Total number of tiles in the system: Input + Hidden + Output
) (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  ///////////////////////////
  // Local Wires and Regs
  ///////////////////////////
  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

  ///////////////////////////
  // Interfaces
  ///////////////////////////
  async_if #(16) links[NUM_TILES]();

  ///////////////////////////
  // Instances
  ///////////////////////////
  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;



  ///////////////////////////
  // Instances
  ///////////////////////////

  // Example: Create a ring of tiles connected by async interfaces
  genvar i;
  generate
      for (i=0;i<NUM_TILES;i++) begin : cim_neuron_tile_
          cim_neuron_tile u_cim_neuron_tile(
              .event_in    (links[i]),
              .event_out   (links[(i+1)%NUM_TILES])
          );
      end
  endgenerate

  // NoC instance
  noc_router #(
      .NUM_INPUT_TILES(8),
      .NUM_HIDDEN_TILES(10),
      .NUM_OUTPUT_TILES(8)
  ) u_noc_router (
      .in_if(links),   // Connect all tile event_out to NoC inputs
      .out_if(links)   // Connect NoC outputs back to tile event_in
  );

  // DMA instance (example: connects ui_in to the first tile's event_in)

  // Peripheral instances (if any)

endmodule
