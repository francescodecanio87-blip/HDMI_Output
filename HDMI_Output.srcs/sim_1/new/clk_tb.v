`timescale 1ns / 1ps

module top_tb;

    reg clk;
    wire hdmi_clk_p;
    wire hdmi_clk_n;
    wire [2:0] hdmi_d_p;
    wire [2:0] hdmi_d_n;

    top dut (
        .clk(clk),
        .hdmi_clk_p(hdmi_clk_p),
        .hdmi_clk_n(hdmi_clk_n),
        .hdmi_d_p(hdmi_d_p),
        .hdmi_d_n(hdmi_d_n)
    );

    initial begin
        clk = 1'b0;
    end

    always #4 clk = ~clk;

    initial begin
        wait (dut.pll_locked === 1'b1);

        repeat (4) @(posedge dut.clk_25);

        if ((^dut.tmds_r === 1'bx) || (^dut.tmds_g === 1'bx) ||
            (^dut.tmds_b === 1'bx)) begin
            $error("TMDS indefinito durante il test del quadrato");
        end

        $display("TEST RGB/DVI AVVIATO: pll_locked=%b h_count=%0d v_count=%0d",
                 dut.pll_locked, dut.u_rgb_gen.h_count, dut.u_rgb_gen.v_count);
        $finish;
    end

endmodule