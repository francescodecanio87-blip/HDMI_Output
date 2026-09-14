// -----------------------------------------------------------------------------
// Module      : RGB_gen
// File        : RGB_gen.v
// Description : 640x480 @ 60 Hz test-pattern generator.
//               Generates a red sine wave with X/Y axes on a black background.
//               The timing uses 800 total pixels and 525 total lines with a
//               25 MHz pixel clock.
//
// Outputs     : VD_R, VD_G, VD_B - RGB video data
//               C0              - horizontal sync control
//               C1              - vertical sync control
//               DE              - active-video enable
// -----------------------------------------------------------------------------

module RGB_gen (
    input  wire       clk_pixel,
    input  wire       resetb,
    output reg  [7:0] VD_R,
    output reg  [7:0] VD_G,
    output reg  [7:0] VD_B,
    output reg        C0,
    output reg        C1,
    output reg        DE
);

    reg [9:0] h_count;
    reg [9:0] v_count;
    reg [31:0] phase_acc;
    reg [4:0] sine_index;
    reg [4:0] sine_next_index;
    reg signed [8:0] sine_offset;
    reg signed [8:0] sine_next_offset;
    integer sine_y;
    integer sine_next_y;
    integer sine_y_interp;
    integer sine_subpixel;

    localparam integer H_ACTIVE = 640;
    localparam integer H_TOTAL  = 800;
    localparam integer V_ACTIVE = 480;
    localparam integer V_TOTAL  = 525;

    localparam integer SINE_CENTER_Y = 240;
    localparam integer SINE_AMPLITUDE = 100;
    localparam integer SINE_PERIODS = 4;
    localparam integer AXIS_X = 80;
    localparam integer AXIS_Y = 240;

    // Phase increment for 15 kHz at a 25 MHz pixel clock:
    // 15,000 / 25,000,000 * 2^32 = 2,576,980.
    localparam [31:0] PHASE_INCREMENT = 32'd10;

    function automatic signed [8:0] sine_lut;
        input [4:0] index;
        begin
            case (index)
                5'd0:  sine_lut = 0;
                5'd1:  sine_lut = 20;
                5'd2:  sine_lut = 38;
                5'd3:  sine_lut = 56;
                5'd4:  sine_lut = 71;
                5'd5:  sine_lut = 83;
                5'd6:  sine_lut = 92;
                5'd7:  sine_lut = 98;
                5'd8:  sine_lut = 100;
                5'd9:  sine_lut = 98;
                5'd10: sine_lut = 92;
                5'd11: sine_lut = 83;
                5'd12: sine_lut = 71;
                5'd13: sine_lut = 56;
                5'd14: sine_lut = 38;
                5'd15: sine_lut = 20;
                5'd16: sine_lut = 0;
                5'd17: sine_lut = -20;
                5'd18: sine_lut = -38;
                5'd19: sine_lut = -56;
                5'd20: sine_lut = -71;
                5'd21: sine_lut = -83;
                5'd22: sine_lut = -92;
                5'd23: sine_lut = -98;
                5'd24: sine_lut = -100;
                5'd25: sine_lut = -98;
                5'd26: sine_lut = -92;
                5'd27: sine_lut = -83;
                5'd28: sine_lut = -71;
                5'd29: sine_lut = -56;
                5'd30: sine_lut = -38;
                default: sine_lut = -20;
            endcase
        end
    endfunction

    always @(posedge clk_pixel or negedge resetb) begin
        if (!resetb) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
            phase_acc <= 32'd0;
        end
        else begin
            phase_acc <= phase_acc + PHASE_INCREMENT;
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end
            else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    always @* begin
        DE = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);

        // 640x480 VGA/DVI timing: active-low sync pulses.
        C0 = !((h_count >= 656) && (h_count < 752));
        C1 = !((v_count >= 490) && (v_count < 492));

        // Interpolate between LUT samples. Without interpolation the LUT
        // changes every five pixels and steep sections appear as dots.
        sine_index = (h_count / 5) + phase_acc[31:27];
        sine_next_index = sine_index + 1'b1;
        sine_subpixel = h_count % 5;
        sine_offset = sine_lut(sine_index);
        sine_next_offset = sine_lut(sine_next_index);
        sine_y = SINE_CENTER_Y + sine_offset;
        sine_next_y = SINE_CENTER_Y + sine_next_offset;
        sine_y_interp = sine_y +
                ((sine_next_y - sine_y) * sine_subpixel) / 5;

        VD_R = 8'h00;
        VD_G = 8'h00;
        VD_B = 8'h00;

        if (DE) begin
            // Gray coordinate axes.
            if ((v_count == AXIS_Y) || (h_count == AXIS_X)) begin
                VD_R = 8'h40;
                VD_G = 8'h40;
                VD_B = 8'h40;
            end

            // Red sine wave, one pixel thick with a small anti-gap tolerance.
            if ((v_count >= sine_y_interp - 2) &&
                (v_count <= sine_y_interp + 2)) begin
                VD_R = 8'hFF;
                VD_G = 8'h00;
                VD_B = 8'h00;
            end
        end
    end

endmodule
