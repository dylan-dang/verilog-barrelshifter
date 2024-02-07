`timescale 1ns / 1ps
`default_nettype none
module barrelshifter_tb #(parameter int D_SIZE = 8)();

    logic                           clk_in;
    logic                           rst_in;
    logic [D_SIZE-1:0]              x_in;
    logic [$clog2(D_SIZE)-1:0]      s_in;
    logic [2:0]                     op_in;
    logic [D_SIZE-1:0]              y_out;
    logic                           zf_out;
    logic                           vf_out;

    // barrelshifter_rtl #(D_SIZE)
    //                 dut(
    //                 .clk_in(clk_in),
    //                 .rst_in(rst_in),
    //                 .x_in(x_in),
    //                 .s_in(s_in),
    //                 .op_in(op_in),
    //                 .y_out(y_out),
    //                 .zf_out(zf_out),
    //                 .vf_out(vf_out)
    //                 );

    barrelshifter_comb_structural #(D_SIZE)
                    dut(
                    .rst_in(rst_in),
                    .x_in(x_in),
                    .s_in(s_in),
                    .op_in(op_in),
                    .y_out(y_out),
                    .zf_out(zf_out),
                    .vf_out(vf_out)
                    );
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("barrelshifter.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,barrelshifter_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message at start
        clk_in = 0; //0 is generally a safe value to initialize with and not specify size
        rst_in = 0;
        x_in = 0;
        s_in = 0;
        op_in = 0;
        #10
        rst_in = 1; //always good to reset
        #10
        rst_in = 0;
        $display("x_in     | s_in | op_in | c_out    | zf_out | vf_out");
        for (int op = 0; op <= 7; op++) begin
            for (int i = 0; i < $pow(2, D_SIZE); i++) begin
                for (int j = 0; j < D_SIZE; j++) begin
                    x_in = i;
                    s_in = j;
                    op_in = op;
                    #10; //wait
                    if (zf_out || vf_out)
                        $display("%b | %b  | %3b   | %b | %1b      | %1b",x_in, s_in, op_in, y_out, zf_out, vf_out); //print values C-style formatting
                end
            end
        end
        $display("Finishing Sim"); //print nice message at end
        $finish;
    end
endmodule: barrelshifter_tb
`default_nettype wire