`timescale 1ns / 1ps
`default_nettype none

// a simple module that gives an RTL description of the barrelshifter.

module  barrelshifter_comb_structural   # (parameter int D_SIZE = 8)
    (
    input wire                  rst_in,
    input wire [D_SIZE-1:0]     x_in,
    input wire [$clog2(D_SIZE)-1:0]     s_in,
    input wire [2:0]            op_in,
    output logic [D_SIZE-1:0]   y_out,
    output logic                zf_out,
    output logic                vf_out
    );

    always @* begin: mainblock
        if (rst_in) begin
            // reset to 0
            y_out = 0;
            zf_out = 0;
            vf_out = 0;
        end 
        else begin
            casex(op_in)
                3'b000: y_out = x_in >> s_in; // shift right logical
                3'b001: y_out = x_in >>> s_in; // shift right arithmetic
                3'b01x: y_out = (x_in >> s_in) | (x_in << (D_SIZE - s_in)); // rotate right
                3'b100: y_out = x_in << s_in; // shift left logical
                3'b101: y_out = ((x_in <<< s_in) & ~(1<<(D_SIZE-1))) | (x_in & (1<<(D_SIZE-1))); // shift left arithmetic
                3'b11x: y_out = (x_in << s_in) | (x_in >> (D_SIZE - s_in)); // rotate left
            endcase
            zf_out = &(~y_out);
            vf_out = ((op_in == 3'b101) && (|((x_in & ~((1<<(D_SIZE - s_in))-1)) == x_in[(D_SIZE-1)]))) ? 1 : 0;
        end
    end: mainblock
endmodule

`default_nettype wire