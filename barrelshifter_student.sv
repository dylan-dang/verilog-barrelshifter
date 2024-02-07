`timescale 1ns / 1ps 
`default_nettype none

// 2^n:1 bus general multiplexer
module mux #(
    parameter int D_SIZE = 1,
    parameter int N = 1
) (
    output wire [D_SIZE-1:0] out,
    input wire [N - 1:0] sel,
    input wire [(1 << N) * D_SIZE - 1:0] in
);
    generate
        if (N == 1) begin
            // base case 2:1 multiplexer
            for (genvar i = 0; i < D_SIZE; i++) begin
                wire and_1, and_2, not_sel;
                not (not_sel, sel[0]);
                and (and_1, in[i], sel);
                and (and_2, in[i + D_SIZE], not_sel);
                or (out[i], and_1, and_2);
            end
        end else begin
            wire [D_SIZE-1:0] out0, out1;
            mux #(D_SIZE, N - 1) m1 (
                    out0,
                    sel[N-2:0],
                    in[(1 << N) * D_SIZE - 1:(1 << (N - 1)) * D_SIZE]
            );
            mux #(D_SIZE, N - 1) m0 (
                    out1,
                    sel[N-2:0],
                    in[(1 << (N - 1)) * D_SIZE - 1:0]
            );
            mux #(D_SIZE) m2 (out, sel[N - 1], {out0, out1});
        end
    endgenerate
endmodule


// bread and butter barrel shifter
module shift #(
    parameter int D_SIZE = 8,
    parameter int DIR = 1,       // -1 for right, 1 for left
    parameter int ARITHMETIC = 0 // boolean
) (
    input wire [D_SIZE-1:0] x_in,
    input wire [$clog2(D_SIZE) - 1:0] s_in,
    input wire arithmetic,
    output wire [D_SIZE - 1:0] y_out
);

    // set up intermediary array of wires
    wire [D_SIZE - 1:0] mid[$clog2(D_SIZE):0];
    assign mid[0] = x_in;
    assign y_out[D_SIZE - 2:0] = mid[$clog2(D_SIZE)][D_SIZE - 2:0];

    // ignore sign bit when arithmetic
    mux m (
        y_out[D_SIZE - 1],
        arithmetic,
        {mid[$clog2(D_SIZE)][D_SIZE - 1], x_in[D_SIZE - 1]}
    );

    generate
        // create an array of multiplexers shifted by 2^n per level
        for (genvar s = 0; s < $clog2(D_SIZE); s++) begin
            for (genvar i = 0; i < D_SIZE; i++) begin
                // index of shifted mux
                localparam j = i - (1 << s) * DIR;

                // bitwise not of s_in
                wire not_s;
                not (not_s, s_in[s]);

                wire fill;
                if (DIR == -1) begin
                    and (fill, arithmetic, x_in[D_SIZE - 1]);
                end else begin
                    assign fill = 1'b0;
                end

                mux m (
                        mid[s+1][i],
                        not_s,
                        {j < 0 || j > D_SIZE - 1 ? fill : mid[s][j], mid[s][i]}
                );
            end
        end
    endgenerate
endmodule

module half_adder (
    input wire a,
    input wire b,
    output wire sum,
    output wire carry
);
    xor (sum, a, b);
    and (carry, a, b);
endmodule

// increment a wire bus and ignore carry
module increment #(
    parameter int WIDTH = 8
) (
    input wire [WIDTH - 1:0] in,
    output wire [WIDTH - 1:0] sum,
    output wire carry
);
    wire [WIDTH:0] inc_carry;
    assign inc_carry[0] = 1'b1;
    assign carry = inc_carry[WIDTH];
    generate
        for (genvar i = 0; i < WIDTH; i++) begin
            half_adder ha (
                    in[i],
                    inc_carry[i],
                    sum[i],
                    inc_carry[i+1]
            );
        end
    endgenerate
endmodule

// invert a wire bus
module invert #(
    parameter int WIDTH = 8
) (
    input wire  [WIDTH - 1:0] in,
    output wire [WIDTH - 1:0] out
);
    generate
        for (genvar i = 0; i < WIDTH; i++) begin
            not (out[i], in[i]);
        end
    endgenerate
endmodule

// xor a bus of wires to a single wire
module xor_bit #(
    parameter int WIDTH = 8
) (
    input wire [WIDTH - 1:0]  in,
    input wire x,
    output wire [WIDTH - 1:0] out
);
    generate
        for (genvar i = 0; i < WIDTH; i++) begin
            xor (out[i], in[i], x);
        end
    endgenerate
endmodule

// get the bitwise or of two wire buses
module bitwise_or #(
    parameter int WIDTH = 8
) (
    input wire  [WIDTH - 1:0] i0,
    input wire  [WIDTH - 1:0] i1,
    output wire [WIDTH - 1:0] out
);
    generate
        for (genvar i = 0; i < WIDTH; i++) begin
            or (out[i], i0[i], i1[i]);
        end
    endgenerate
endmodule

// get the bitwise or of two wire buses
module bitwise_and #(
    parameter int WIDTH = 8
) (
    input wire  [WIDTH - 1:0] i0,
    input wire  [WIDTH - 1:0] i1,
    output wire [WIDTH - 1:0] out
);
    generate
        for (genvar i = 0; i < WIDTH; i++) begin
            and (out[i], i0[i], i1[i]);
        end
    endgenerate
endmodule


// perform or on every bit recursively, assume width is 2^n >= 2
module or_reduction #(
    parameter int WIDTH = 8
) (
    input wire [WIDTH - 1:0] in,
    output wire out
);
    generate
        if (WIDTH == 1) begin
            assign out = in[0];
        end else begin
            wire [WIDTH / 2 - 1:0] layer;
            for (genvar i = 0; i < WIDTH; i = i + 2) begin
                or (layer[i / 2], in[i], in[i + 1]);
            end
            or_reduction #(WIDTH / 2) reduce (layer, out);
        end
    endgenerate
endmodule

// main calling module
// 000: shift right logical
// 001: shift right arithmetic
// 01x: rotate right
// 100: shift left logical
// 101: shift left arithmetic
// 11x: rotate left
module barrelshifter_comb_structural #(
    parameter int D_SIZE = 8
) (
    input wire rst_in,
    input wire [D_SIZE-1:0] x_in,
    input wire [$clog2(D_SIZE) - 1:0] s_in,
    input wire [2:0] op_in,
    output logic [D_SIZE-1:0] y_out,
    output logic zf_out,
    output logic vf_out
);

    // look up table to check if op_in is arithmetic left shift (101)
    wire is_als, is_ars;
    mux #(.N(3)) als_lut (is_als, op_in, 8'b00000100);
    mux #(.N(3)) ars_lut (is_ars, op_in, 8'b01000000);

    wire [D_SIZE - 1:0] y,    // output when rst
                        out,  // output from shifter
                        rs,   // right shift
                        rot,  // rotate
                        ls;   // left shift

    // calculate s's 2 bit complement, (~s + 1) to get rotation adjustment shift
    wire [$clog2(D_SIZE) - 1:0] not_s, s_c, ls_s, rs_s;
    invert #($clog2(D_SIZE)) inv (s_in, not_s);
    increment #($clog2(D_SIZE)) inc (.in (not_s), .sum(s_c));

    // get rotation adjustments
    mux #($clog2(D_SIZE), 3) lrot_adj (
            rs_s,
            op_in,
            {{6{s_in}}, {2{s_c}}}
    );
    mux #($clog2(D_SIZE), 3) rrot_adj (
            ls_s,
            op_in,
            {{2{s_in}}, {2{s_c}}, {4{s_in}}}
    );

    // perform shifts
    shift #(D_SIZE, -1) right_shift (x_in, rs_s, is_ars, rs);
    shift #(D_SIZE) left_shift (x_in, ls_s, is_als, ls);

    // or rotation adjustment with shift to get rotation
    bitwise_or #(D_SIZE) rot_or (rs, ls, rot);

    // choose result from opcode
    mux #(D_SIZE, 3) op_case (
            out,
            op_in,
            {{2{rs}}, {2{rot}}, {2{ls}}, {2{rot}}}
    );

    wire y_reduced, zf, zf_rst;
    wire vf_pre, vf, vf_rst;
    wire [D_SIZE-1:0] premask, mask, masked_x, xor_x_sign;

    // perform zf_out = ~|(y_out);
    or_reduction #(D_SIZE) y_reduce (y_out, y_reduced);
    not (zf_rst, y_reduced);

    // xor x_in with sign of x_in
    xor_bit #(D_SIZE) xxor (x_in, x_in[D_SIZE-1], xor_x_sign);

    // shift filled bus by shift complement to get mask
    shift #(D_SIZE) sh_mask ({D_SIZE{1'b1}}, not_s , 1'b1, mask);

    // (xor_x_sign & mask)
    bitwise_and #(D_SIZE) and_mask (xor_x_sign, mask, masked_x);

    // |(xor_x_sign & mask)
    or_reduction #(D_SIZE) or_x (masked_x, vf_pre);

    // (op_in == 3'b101) && vf_pre
    and (vf_rst, is_als, vf_pre);

    // check reset pin
    mux #(D_SIZE) y_mux (y, rst_in, {out, {D_SIZE{1'b0}}});
    mux zf_mux (zf, rst_in, {zf_rst, 1'b0});
    mux vf_mux (vf, rst_in, {vf_rst, 1'b0});

    always @* begin
        y_out  = y;
        vf_out = vf;
        zf_out = zf;
    end
endmodule
