
// ============================================================
// synapse_mem.sv
// Signed integer synapse memory with local update capability
// ============================================================

module synapse_mem #(
    parameter NUM_SYNAPSES = 256,
    parameter WEIGHT_WIDTH = 8
)(
    input  logic [$clog2(NUM_SYNAPSES)-1:0] addr,
    input  logic signed [WEIGHT_WIDTH-1:0]  delta,
    input  logic                            update_en,
    output logic signed [WEIGHT_WIDTH-1:0]  weight_out
);

    logic signed [WEIGHT_WIDTH-1:0] mem [0:NUM_SYNAPSES-1];

    // Read
    assign weight_out = mem[addr];

    // Local plasticity update (event driven)
    always_comb begin
        if (update_en) begin
            mem[addr] = mem[addr] + delta;
        end
    end

    `ifdef FORMAL
        assert property (@(posedge clk) update_en |-> $stable(addr));
    `endif

endmodule
