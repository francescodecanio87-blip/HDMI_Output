`timescale 1ns / 1ps

module top (
    input  wire       clk,
    output wire       hdmi_clk_p,
    output wire       hdmi_clk_n,
    output wire [2:0] hdmi_d_p,
    output wire [2:0] hdmi_d_n
);

    wire clk_125;
    wire clk_25;
    wire pll_locked;
    wire [9:0] tmds_r;
    wire [9:0] tmds_g;
    wire [9:0] tmds_b;
    wire [7:0] VD_R;
    wire [7:0] VD_G;
    wire [7:0] VD_B;
    wire C0;
    wire C1;
    wire DE;
    wire dvi_clk_single;
    wire [2:0] dvi_data_single;

    ip_clk u_ip_clk (
        .clk_in1 (clk),
        .reset   (1'b0),
        .clk_250 (),
        .clk_125 (clk_125),
        .clk_25  (clk_25),
        .locked  (pll_locked)
    );

    RGB_gen u_rgb_gen (
        .clk_pixel (clk_25),
        .resetb    (pll_locked),
        .VD_R      (VD_R),
        .VD_G      (VD_G),
        .VD_B      (VD_B),
        .C0        (C0),
        .C1        (C1),
        .DE        (DE)
    );

    TMDS_Encoder u_tmds_encoder_r (
        .clk_pixel (clk_25), .VD (VD_R), .C0 (1'b0), .C1 (1'b0),
        .DE (DE), .resetb (pll_locked), .TMDS (tmds_r)
    );

    TMDS_Encoder u_tmds_encoder_g (
        .clk_pixel (clk_25), .VD (VD_G), .C0 (1'b0), .C1 (1'b0),
        .DE (DE), .resetb (pll_locked), .TMDS (tmds_g)
    );

    TMDS_Encoder u_tmds_encoder_b (
        .clk_pixel (clk_25), .VD (VD_B), .C0 (C0), .C1 (C1),
        .DE (DE), .resetb (pll_locked), .TMDS (tmds_b)
    );

    TMDS_Serializer u_serializer_r (
        .clk_serial (clk_125), .clk_pixel (clk_25), .reset (~pll_locked),
        .data (tmds_r), .serial_out (dvi_data_single[2])
    );

    TMDS_Serializer u_serializer_g (
        .clk_serial (clk_125), .clk_pixel (clk_25), .reset (~pll_locked),
        .data (tmds_g), .serial_out (dvi_data_single[1])
    );

    TMDS_Serializer u_serializer_b (
        .clk_serial (clk_125), .clk_pixel (clk_25), .reset (~pll_locked),
        .data (tmds_b), .serial_out (dvi_data_single[0])
    );

    ODDR #(.DDR_CLK_EDGE ("SAME_EDGE")) u_dvi_clock_oddr (
        .Q (dvi_clk_single), .C (clk_25), .CE (pll_locked),
        .D1 (1'b1), .D2 (1'b0), .R (~pll_locked), .S (1'b0)
    );

    OBUFDS #(.IOSTANDARD ("TMDS_33")) u_dvi_clock_obufds (
        .I (dvi_clk_single), .O (hdmi_clk_p), .OB (hdmi_clk_n)
    );

    genvar lane;
    generate
        for (lane = 0; lane < 3; lane = lane + 1) begin : gen_dvi_data
            OBUFDS #(.IOSTANDARD ("TMDS_33")) u_dvi_data_obufds (
                .I (dvi_data_single[lane]),
                .O (hdmi_d_p[lane]), .OB (hdmi_d_n[lane])
            );
        end
    endgenerate

endmodule

module TMDS_Serializer (
    input  wire       clk_serial,
    input  wire       clk_pixel,
    input  wire       reset,
    input  wire [9:0] data,
    output wire       serial_out
);

    wire shift_out_1;
    wire shift_out_2;

    OSERDESE2 #(
        .DATA_RATE_OQ ("DDR"), .DATA_RATE_TQ ("SDR"), .DATA_WIDTH (10),
        .INIT_OQ (1'b0), .INIT_TQ (1'b0), .SERDES_MODE ("MASTER"),
        .SRVAL_OQ (1'b0), .SRVAL_TQ (1'b0), .TBYTE_CTL ("FALSE"),
        .TBYTE_SRC ("FALSE"), .TRISTATE_WIDTH (1)
    ) u_oserdes_master (
        .CLK (clk_serial), .CLKDIV (clk_pixel),
        .D1 (data[0]), .D2 (data[1]), .D3 (data[2]), .D4 (data[3]),
        .D5 (data[4]), .D6 (data[5]), .D7 (data[6]), .D8 (data[7]),
        .OCE (1'b1), .OQ (serial_out), .RST (reset),
        .SHIFTIN1 (shift_out_1), .SHIFTIN2 (shift_out_2),
        .T1 (1'b0), .T2 (1'b0), .T3 (1'b0), .T4 (1'b0),
        .TBYTEIN (1'b0), .TCE (1'b0), .SHIFTOUT1 (), .SHIFTOUT2 ()
    );

    OSERDESE2 #(
        .DATA_RATE_OQ ("DDR"), .DATA_RATE_TQ ("SDR"), .DATA_WIDTH (10),
        .INIT_OQ (1'b0), .INIT_TQ (1'b0), .SERDES_MODE ("SLAVE"),
        .SRVAL_OQ (1'b0), .SRVAL_TQ (1'b0), .TBYTE_CTL ("FALSE"),
        .TBYTE_SRC ("FALSE"), .TRISTATE_WIDTH (1)
    ) u_oserdes_slave (
        .CLK (clk_serial), .CLKDIV (clk_pixel),
        .D1 (1'b0), .D2 (1'b0), .D3 (data[8]), .D4 (data[9]),
        .D5 (1'b0), .D6 (1'b0), .D7 (1'b0), .D8 (1'b0),
        .OCE (1'b1), .OQ (), .RST (reset),
        .SHIFTIN1 (1'b0), .SHIFTIN2 (1'b0),
        .T1 (1'b0), .T2 (1'b0), .T3 (1'b0), .T4 (1'b0),
        .TBYTEIN (1'b0), .TCE (1'b0),
        .SHIFTOUT1 (shift_out_1), .SHIFTOUT2 (shift_out_2)
    );

endmodule
