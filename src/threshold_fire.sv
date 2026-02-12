
// ============================================================
// threshold_fire.sv
// Comparator and spike generation logic
// ============================================================

module threshold_fire #(
    parameter MEM_WIDTH = 16
)(
    input  logic signed [MEM_WIDTH-1:0] membrane,
    input  logic signed [MEM_WIDTH-1:0] threshold,
    output logic                        spike
);

    assign spike = (membrane >= threshold);

endmodule
