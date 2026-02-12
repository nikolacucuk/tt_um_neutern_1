
interface async_if #(parameter WIDTH = 32);
    logic req;
    logic ack;
    logic [WIDTH-1:0] data;

    modport sender (output req, input ack, output data);
    modport receiver (input req, output ack, input data);
endinterface
