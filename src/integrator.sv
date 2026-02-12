
// ============================================================
// integrator.sv
// Event-driven membrane potential accumulator
// ============================================================

module integrator #(
    parameter MEM_WIDTH = 16
)(
    input  logic signed [MEM_WIDTH-1:0] input_delta,
    input  logic                        integrate_en,
    input  logic                        leak_en,
    input  logic signed [MEM_WIDTH-1:0] leak_step,
    output logic signed [MEM_WIDTH-1:0] membrane
);

    logic signed [MEM_WIDTH-1:0] mem_reg;

    assign membrane = mem_reg;

    always_comb begin
        if (integrate_en) begin
            mem_reg = mem_reg + input_delta;
        end
        else if (leak_en) begin
            if (mem_reg > 0)
                mem_reg = mem_reg - leak_step;
            else if (mem_reg < 0)
                mem_reg = mem_reg + leak_step;
        end
    end

endmodule
