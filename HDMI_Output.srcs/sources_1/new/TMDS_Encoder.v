// -----------------------------------------------------------------------------
// Module      : TMDS_Encoder
// File        : TMDS_Encoder.v
// Description : TMDS encoder logic for the PL video domain.
//               Generates the clk_125 output from clk_250 and uses reset
//               as an active-low asynchronous reset.
//
// Inputs      : clk_250 - 250 MHz input clock
//               D       - 8-bit input data
//               C0, C1  - Control inputs
//               DE      - Data enable
//               resetb  - Active-low asynchronous reset
// Output      : clk_125 - Generated output clock
//
// Revision History:
// Date         Author            Description
// -----------------------------------------------------------------------------
// 2026-09-11   Francesco De Canio  Initial version
// -----------------------------------------------------------------------------

module TMDS_Encoder(
    input clk_pixel,
    input [7:0] VD,
    input C0,
    input C1,
    input DE,
    input resetb,
    output reg [9:0] TMDS
    );

    wire [1:0] CD = {C1, C0};
    wire [3:0] cnt_ones = VD[0] + VD[1] + VD[2] + VD[3] +
                          VD[4] + VD[5] + VD[6] + VD[7];
    wire use_xnor = (cnt_ones > 4'd4) ||
                    ((cnt_ones == 4'd4) && (VD[0] == 1'b0));
    reg [8:0] q_m;
    reg signed [4:0] balance_acc;
    reg [3:0] q_m_ones;
    integer bit_index;

    always @* begin
        q_m[0] = VD[0];
        for (bit_index = 1; bit_index < 8; bit_index = bit_index + 1) begin
            q_m[bit_index] = q_m[bit_index - 1] ^
                             (use_xnor ? ~VD[bit_index] : VD[bit_index]);
        end
        q_m[8] = ~use_xnor;

        q_m_ones = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                   q_m[4] + q_m[5] + q_m[6] + q_m[7];
    end

    always @(posedge clk_pixel or negedge resetb) begin
        if (!resetb) begin
            TMDS <= 10'b0;
            balance_acc <= 5'sd0;
        end
        else if (!DE) begin
            case (CD)
                2'b00: TMDS <= 10'b1101010100;
                2'b01: TMDS <= 10'b0010101011;
                2'b10: TMDS <= 10'b0101010100;
                default: TMDS <= 10'b1010101011;
            endcase
            balance_acc <= 5'sd0;
        end
        else if ((balance_acc == 5'sd0) || (q_m_ones == 4'd4)) begin
            TMDS[9] <= ~q_m[8];
            TMDS[8] <= q_m[8];
            TMDS[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
            balance_acc <= balance_acc +
                           (q_m[8] ? $signed({1'b0, q_m_ones}) - 5'sd4
                                   : 5'sd4 - $signed({1'b0, q_m_ones}));
        end
        else if (((balance_acc > 0) && (q_m_ones > 4'd4)) ||
                 ((balance_acc < 0) && (q_m_ones < 4'd4))) begin
            TMDS <= {1'b1, q_m[8], ~q_m[7:0]};
            balance_acc <= balance_acc -
                           (q_m[8] ? $signed({1'b0, q_m_ones}) - 5'sd4
                                   : 5'sd4 - $signed({1'b0, q_m_ones}));
        end
        else begin
            TMDS <= {1'b0, q_m[8], q_m[7:0]};
            balance_acc <= balance_acc +
                           (q_m[8] ? $signed({1'b0, q_m_ones}) - 5'sd4
                                   : 5'sd4 - $signed({1'b0, q_m_ones}));
        end
    end

endmodule
