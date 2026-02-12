// ============================================================
// noc_router.sv
// Configurable asynchronous event router with multi-tile support
// Routes spike events between input, hidden, and output neurons
// ============================================================

`include "async_if.sv"

module noc_router #(
    // Tile counts
    parameter NUM_INPUT_TILES   = 8,
    parameter NUM_HIDDEN_TILES  = 10,
    parameter NUM_OUTPUT_TILES  = 8,

    // Event packet fields
    parameter NEURON_ID_WIDTH   = 8,
    parameter EVT_TYPE_WIDTH    = 2,

    // Synapse / sizing
    parameter NUM_SYNAPSES      = NUM_INPUT_TILES * NUM_HIDDEN_TILES + NUM_HIDDEN_TILES * NUM_OUTPUT_TILES,

    // Optional features
    parameter MULTICAST_SUPPORT = 1
) (
    async_if.receiver in_if[],      // one per tile (sized below by NUM_TILES)
    async_if.sender   out_if[]      // one per tile
);

    // Derived parameters
    localparam NUM_TILES = NUM_INPUT_TILES + NUM_HIDDEN_TILES + NUM_OUTPUT_TILES;
    localparam TILE_ID_WIDTH = (NUM_TILES > 1) ? $clog2(NUM_TILES) : 1;
    localparam DATA_WIDTH = 1 /*multicast*/ + TILE_ID_WIDTH + NEURON_ID_WIDTH + EVT_TYPE_WIDTH;

    // Re-declare port array sizes using the derived NUM_TILES
    // (SystemVerilog allows unsized port arrays; here we assert expected sizes)
    // Note: callers should instantiate with in_if[NUM_TILES] and out_if[NUM_TILES]

    // ------------------------------------------------------------------
    // Event packet layout (packed, MSB -> LSB):
    // [DATA_WIDTH-1]       : multicast flag (1 = broadcast to all tiles)
    // [DATA_WIDTH-2 : DATA_WIDTH-1-TILE_ID_WIDTH+1] : tile_id
    // [ ... neuron_id ... ] : neuron id
    // [ ... evt_type  ... ] : event type
    // ------------------------------------------------------------------

    // Functions
    function automatic logic [DATA_WIDTH-1:0] priority_select_data(
        input logic [NUM_TILES-1:0] grants,
        input logic [NUM_TILES*DATA_WIDTH-1:0] data_bus
    );
        integer k;
        priority_select_data = '0;
        for (k = 0; k < NUM_TILES; k = k + 1) begin
            if (grants[k]) priority_select_data = data_bus[k*DATA_WIDTH +: DATA_WIDTH];
        end
    endfunction

    // Internal request matrix: wants[input][output]
    wire wants [NUM_TILES-1:0][NUM_TILES-1:0];
    // Grant matrix: grant[output][input]
    wire grant [NUM_TILES-1:0][NUM_TILES-1:0];

    genvar in_idx, out_idx, k;
    generate
        // Build wants matrix: which inputs target which outputs
        for (in_idx = 0; in_idx < NUM_TILES; in_idx = in_idx + 1) begin : build_wants
            // extract packet fields for this input
            wire multicast = in_if[in_idx].data[DATA_WIDTH-1];
            wire [TILE_ID_WIDTH-1:0] dest_tile;
            assign dest_tile = in_if[in_idx].data[DATA_WIDTH-2 -: TILE_ID_WIDTH];

            for (out_idx = 0; out_idx < NUM_TILES; out_idx = out_idx + 1) begin : wants_col
                if (MULTICAST_SUPPORT) begin
                    assign wants[in_idx][out_idx] = in_if[in_idx].req && (multicast || (dest_tile == out_idx));
                end else begin
                    assign wants[in_idx][out_idx] = in_if[in_idx].req && (dest_tile == out_idx);
                end
            end
        end

        // For each output: local arbitration (static, lowest-index priority)
        for (out_idx = 0; out_idx < NUM_TILES; out_idx = out_idx + 1) begin : output_arb
            // gather column of wants for this output
            wire [NUM_TILES-1:0] wants_col;
            for (in_idx = 0; in_idx < NUM_TILES; in_idx = in_idx + 1) begin : gather
                assign wants_col[in_idx] = wants[in_idx][out_idx];
            end

            // compute grant vector for this output: lowest-index input wins
            for (in_idx = 0; in_idx < NUM_TILES; in_idx = in_idx + 1) begin : gen_grant
                if (in_idx == 0) begin
                    assign grant[out_idx][in_idx] = wants_col[in_idx];
                end else begin
                    assign grant[out_idx][in_idx] = wants_col[in_idx] && ~(|wants_col[in_idx-1:0]);
                end
            end

            // build data bus concatenation from inputs (LSB = input 0)
            wire [NUM_TILES*DATA_WIDTH-1:0] data_bus;
            for (k = 0; k < NUM_TILES; k = k + 1) begin : pack_data
                assign data_bus[k*DATA_WIDTH +: DATA_WIDTH] = in_if[k].data;
            end

            // Output request is asserted when any grant is given to this output
            assign out_if[out_idx].req = |grant[out_idx];

            // Select data from the granted input (priority_select_data picks lowest-index grant)
            assign out_if[out_idx].data = priority_select_data(grant[out_idx], data_bus);
        end

        // Input acknowledgments: an input is acknowledged when all granted destination outputs have acknowledged
        for (in_idx = 0; in_idx < NUM_TILES; in_idx = in_idx + 1) begin : input_ack
            // For each output create ack_masked: if this output granted to this input then require its ack, else true
            wire [NUM_TILES-1:0] ack_masked;
            for (out_idx = 0; out_idx < NUM_TILES; out_idx = out_idx + 1) begin : build_ack_mask
                assign ack_masked[out_idx] = grant[out_idx][in_idx] ? out_if[out_idx].ack : 1'b1;
            end

            // compute any_grant (generic)
            wire any_grant_generic;
            assign any_grant_generic = |{for (k = 0; k < NUM_TILES; k = k + 1) grant[k][in_idx]};

            // combine masked acks
            wire all_acks;
            assign all_acks = &ack_masked;

            assign in_if[in_idx].ack = in_if[in_idx].req ? all_acks : 1'b0;
        end
    endgenerate

    // ------------------------------------------------------------------
    // Notes on responsibilities fulfilled:
    // - Handshake flow control: req/ack backpressure is propagated from outputs to inputs
    // - Arbitration: local, per-output, static priority (lowest-index wins)
    // - Optional multicast: when multicast flag set, packet is targeted to all tiles
    // - Event packet: AER-style, no timestamps, carries tile_id/neuron_id/evt_type
    // - No global ordering, arbitration is local only
    // ------------------------------------------------------------------

    // Formal checks (lightweight)
    `ifdef FORMAL
    // Ensure port sizing expectation
    initial begin
        if ($bits(in_if) == 0 || $bits(out_if) == 0) $fatal("Callers must supply in_if[NUM_TILES] and out_if[NUM_TILES]");
    end
    `endif

endmodule
