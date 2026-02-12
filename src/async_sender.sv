
module async_sender #(parameter WIDTH=32)(
    input  logic send_valid,
    input  logic [WIDTH-1:0] send_data,
    async_if.sender link
);

    // Clockless asynchronous sender - combinational logic only
    assign link.req  = send_valid;
    assign link.data = send_data;

endmodule
