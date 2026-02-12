
// ============================================================
// cim_neuron_tile.sv
// Top-level CIM neuron tile (clockless, event-driven)
// ============================================================

`include "async_if.sv"

module cim_neuron_tile #(
    parameter NUM_SYNAPSES = 256,
    parameter WEIGHT_WIDTH = 8,
    parameter MEM_WIDTH    = 16
)(
    async_if.receiver event_in,
    async_if.sender   event_out
);

    logic [$clog2(NUM_SYNAPSES)-1:0] addr;
    logic signed [WEIGHT_WIDTH-1:0] weight;
    logic signed [MEM_WIDTH-1:0]    membrane;
    logic spike;

    // Synapse memory
    synapse_mem #(
        .NUM_SYNAPSES(NUM_SYNAPSES),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) u_syn_mem (
        .addr(addr),
        .delta('0),
        .update_en(1'b0),
        .weight_out(weight)
    );

    // Integrator
    integrator #(
        .MEM_WIDTH(MEM_WIDTH)
    ) u_integrator (
        .input_delta(weight),
        .integrate_en(event_in.req),
        .leak_en(1'b0),
        .leak_step('0),
        .membrane(membrane)
    );

    // Threshold block
    threshold_fire #(
        .MEM_WIDTH(MEM_WIDTH)
    ) u_thresh (
        .membrane(membrane),
        .threshold(16'sd100),
        .spike(spike)
    );

    // Output event logic (4-phase handshake)
    always_comb begin
        if (spike) begin
            event_out.data = membrane;
            event_out.req  = 1'b1;
        end
        else begin
            event_out.req  = 1'b0;
        end
    end

endmodule
