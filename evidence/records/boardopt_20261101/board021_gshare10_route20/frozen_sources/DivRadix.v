// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module DivRadix (
  input  wire          io_flush,
  input  wire          io_cmd_valid,
  output wire          io_cmd_ready,
  input  wire [31:0]   io_cmd_payload_a,
  input  wire [31:0]   io_cmd_payload_b,
  input  wire          io_cmd_payload_normalized,
  input  wire [3:0]    io_cmd_payload_iterations,
  output wire          io_rsp_valid,
  input  wire          io_rsp_ready,
  output wire [31:0]   io_rsp_payload_result,
  output wire [31:0]   io_rsp_payload_remain,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  wire       [33:0]   _zz_div3;
  wire       [32:0]   _zz_div3_1;
  wire       [32:0]   _zz_div3_2;
  wire       [7:0]    _zz_shifter_1;
  wire       [15:0]   _zz_shifter_2;
  wire       [23:0]   _zz_shifter_3;
  wire       [29:0]   _zz_shifter_4;
  reg        [3:0]    counter;
  reg                 busy;
  wire                io_rsp_fire;
  reg                 done;
  wire                when_DivRadix_l45;
  reg        [31:0]   shifter;
  reg        [31:0]   numerator;
  reg        [31:0]   result;
  reg        [33:0]   div1;
  reg        [33:0]   div3;
  wire       [33:0]   div2;
  wire       [33:0]   shifted;
  wire       [34:0]   sub1;
  wire       [34:0]   sub2;
  wire       [34:0]   sub3;
  wire                when_DivRadix_l64;
  reg        [33:0]   _zz_shifter;
  wire                when_DivRadix_l68;
  wire                when_DivRadix_l73;
  wire                when_DivRadix_l77;
  wire                slicesZero_0;
  wire                slicesZero_1;
  wire                slicesZero_2;
  wire       [2:0]    shiftSel;
  wire       [3:0]    _zz_sel;
  wire                _zz_sel_1;
  wire                _zz_sel_2;
  wire                _zz_sel_3;
  reg        [3:0]    _zz_sel_4;
  wire       [3:0]    _zz_sel_5;
  wire                _zz_sel_6;
  wire                _zz_sel_7;
  wire                _zz_sel_8;
  wire       [1:0]    sel;
  reg                 wasBusy;
  wire                when_DivRadix_l93;

  assign _zz_div3_1 = {1'b0,io_cmd_payload_b};
  assign _zz_div3 = {1'd0, _zz_div3_1};
  assign _zz_div3_2 = ({1'd0,io_cmd_payload_b} <<< 1'd1);
  assign _zz_shifter_1 = io_cmd_payload_a[31 : 24];
  assign _zz_shifter_2 = io_cmd_payload_a[31 : 16];
  assign _zz_shifter_3 = io_cmd_payload_a[31 : 8];
  assign _zz_shifter_4 = io_cmd_payload_a[31 : 2];
  assign io_rsp_fire = (io_rsp_valid && io_rsp_ready);
  assign when_DivRadix_l45 = (busy && (counter == 4'b1111));
  assign div2 = (div1 <<< 1);
  assign shifted = {shifter,numerator[31 : 30]};
  assign sub1 = ({1'b0,shifted} - {1'b0,div1});
  assign sub2 = ({1'b0,shifted} - {1'b0,div2});
  assign sub3 = ({1'b0,shifted} - {1'b0,div3});
  assign io_rsp_valid = done;
  assign io_rsp_payload_result = result;
  assign io_rsp_payload_remain = shifter;
  assign io_cmd_ready = (! busy);
  assign when_DivRadix_l64 = (! done);
  always @(*) begin
    _zz_shifter = shifted;
    if(when_DivRadix_l68) begin
      _zz_shifter = sub1[33:0];
    end
    if(when_DivRadix_l73) begin
      _zz_shifter = sub2[33:0];
    end
    if(when_DivRadix_l77) begin
      _zz_shifter = sub3[33:0];
    end
  end

  assign when_DivRadix_l68 = (! sub1[34]);
  assign when_DivRadix_l73 = (! sub2[34]);
  assign when_DivRadix_l77 = (! sub3[34]);
  assign slicesZero_0 = (io_cmd_payload_a[15 : 8] == 8'h0);
  assign slicesZero_1 = (io_cmd_payload_a[23 : 16] == 8'h0);
  assign slicesZero_2 = (io_cmd_payload_a[31 : 24] == 8'h0);
  assign shiftSel = {(&slicesZero_2),(&{slicesZero_2,slicesZero_1}),(&{slicesZero_2,slicesZero_1,slicesZero_0})};
  assign _zz_sel = {1'b1,shiftSel};
  assign _zz_sel_1 = _zz_sel[0];
  assign _zz_sel_2 = _zz_sel[1];
  assign _zz_sel_3 = _zz_sel[2];
  always @(*) begin
    _zz_sel_4[0] = (_zz_sel_1 && (! 1'b0));
    _zz_sel_4[1] = (_zz_sel_2 && (! _zz_sel_1));
    _zz_sel_4[2] = (_zz_sel_3 && (! (|{_zz_sel_2,_zz_sel_1})));
    _zz_sel_4[3] = (_zz_sel[3] && (! (|{_zz_sel_3,_zz_sel_2,_zz_sel_1})));
  end

  assign _zz_sel_5 = _zz_sel_4;
  assign _zz_sel_6 = _zz_sel_5[3];
  assign _zz_sel_7 = (_zz_sel_5[1] || _zz_sel_6);
  assign _zz_sel_8 = (_zz_sel_5[2] || _zz_sel_6);
  assign sel = {_zz_sel_8,_zz_sel_7};
  assign when_DivRadix_l93 = (! busy);
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      busy <= 1'b0;
      done <= 1'b0;
      wasBusy <= 1'b0;
    end else begin
      if(io_rsp_fire) begin
        busy <= 1'b0;
      end
      if(when_DivRadix_l45) begin
        done <= 1'b1;
      end
      if(io_rsp_fire) begin
        done <= 1'b0;
      end
      wasBusy <= busy;
      if(when_DivRadix_l93) begin
        busy <= io_cmd_valid;
      end
      if(io_flush) begin
        done <= 1'b0;
        busy <= 1'b0;
      end
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(when_DivRadix_l64) begin
      counter <= (counter + 4'b0001);
      result <= (result <<< 2);
      if(when_DivRadix_l68) begin
        result[1 : 0] <= 2'b01;
      end
      if(when_DivRadix_l73) begin
        result[1 : 0] <= 2'b10;
      end
      if(when_DivRadix_l77) begin
        result[1 : 0] <= 2'b11;
      end
      shifter <= _zz_shifter[31:0];
      numerator <= (numerator <<< 2);
    end
    if(when_DivRadix_l93) begin
      div1 <= {2'd0, io_cmd_payload_b};
      div3 <= (_zz_div3 + {1'b0,_zz_div3_2});
      result <= ((io_cmd_payload_b == 32'h0) ? 32'hffffffff : 32'h0);
      case(sel)
        2'b11 : begin
          counter <= 4'b0000;
          shifter <= 32'h0;
          numerator <= (io_cmd_payload_a <<< 0);
        end
        2'b10 : begin
          counter <= 4'b0100;
          shifter <= {24'd0, _zz_shifter_1};
          numerator <= (io_cmd_payload_a <<< 8);
        end
        2'b01 : begin
          counter <= 4'b1000;
          shifter <= {16'd0, _zz_shifter_2};
          numerator <= (io_cmd_payload_a <<< 16);
        end
        default : begin
          counter <= 4'b1100;
          shifter <= {8'd0, _zz_shifter_3};
          numerator <= (io_cmd_payload_a <<< 24);
        end
      endcase
      if(io_cmd_payload_normalized) begin
        counter <= (4'b1111 - io_cmd_payload_iterations);
        shifter <= {2'd0, _zz_shifter_4};
        numerator <= (io_cmd_payload_a <<< 30);
      end
    end
  end


endmodule
