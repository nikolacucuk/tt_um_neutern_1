
module async_receiver #(parameter WIDTH=32)(
    output logic recv_valid,
    output logic [WIDTH-1:0] recv_data,
    async_if.receiver link
);

    // Clockless asynchronous receiver - combinational logic only
    assign recv_valid = link.req;        // Valid when request is asserted
    assign recv_data  = link.data;       // Data is available when request is high
    assign link.ack   = link.req;        // Acknowledge immediately when request received

endmodule
