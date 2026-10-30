  assign LsuL1Plugin_logic_refill_slots_6_loadedDone = (LsuL1Plugin_logic_refill_slots_6_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_6_free = ((! LsuL1Plugin_logic_refill_slots_6_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_6_fire = ((LsuL1Plugin_logic_refill_slots_6_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_6_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_7_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
          end
          3'b010 : begin
          end
          3'b011 : begin
          end
          3'b100 : begin
          end
          3'b101 : begin
          end
          3'b110 : begin
          end
          default : begin
            LsuL1Plugin_logic_refill_slots_7_loadedSet = 1'b1;
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_7_loadedDone = (LsuL1Plugin_logic_refill_slots_7_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_7_free = ((! LsuL1Plugin_logic_refill_slots_7_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_7_fire = ((LsuL1Plugin_logic_refill_slots_7_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_7_loadedDone);
  assign _zz_LsuL1Plugin_logic_refill_free = {LsuL1Plugin_logic_refill_slots_7_free,LsuL1Plugin_logic_refill_slots_6_free,LsuL1Plugin_logic_refill_slots_5_free,LsuL1Plugin_logic_refill_slots_4_free,LsuL1Plugin_logic_refill_slots_3_free,LsuL1Plugin_logic_refill_slots_2_free,LsuL1Plugin_logic_refill_slots_1_free,LsuL1Plugin_logic_refill_slots_0_free};
  assign _zz_LsuL1Plugin_logic_refill_free_1 = (_zz_LsuL1Plugin_logic_refill_free & (~ _zz__zz_LsuL1Plugin_logic_refill_free_1));
  assign LsuL1Plugin_logic_refill_free = {_zz_LsuL1Plugin_logic_refill_free_1[7],_zz_LsuL1Plugin_logic_refill_free_1[6],_zz_LsuL1Plugin_logic_refill_free_1[5],_zz_LsuL1Plugin_logic_refill_free_1[4],_zz_LsuL1Plugin_logic_refill_free_1[3],_zz_LsuL1Plugin_logic_refill_free_1[2],_zz_LsuL1Plugin_logic_refill_free_1[1],LsuL1Plugin_logic_refill_slots_0_free};
  assign LsuL1Plugin_logic_refill_full = (&{(! LsuL1Plugin_logic_refill_slots_7_free),(! LsuL1Plugin_logic_refill_slots_6_free),(! LsuL1Plugin_logic_refill_slots_5_free),(! LsuL1Plugin_logic_refill_slots_4_free),(! LsuL1Plugin_logic_refill_slots_3_free),(! LsuL1Plugin_logic_refill_slots_2_free),(! LsuL1Plugin_logic_refill_slots_1_free),(! LsuL1Plugin_logic_refill_slots_0_free)});
  assign when_LsuL1Plugin_l384 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[0]);
  assign when_LsuL1Plugin_l388 = LsuL1Plugin_logic_refill_free[0];
  assign when_LsuL1Plugin_l384_1 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[1]);
  assign when_LsuL1Plugin_l388_1 = LsuL1Plugin_logic_refill_free[1];
  assign when_LsuL1Plugin_l384_2 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[2]);
  assign when_LsuL1Plugin_l388_2 = LsuL1Plugin_logic_refill_free[2];
  assign when_LsuL1Plugin_l384_3 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[3]);
  assign when_LsuL1Plugin_l388_3 = LsuL1Plugin_logic_refill_free[3];
  assign when_LsuL1Plugin_l384_4 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[4]);
  assign when_LsuL1Plugin_l388_4 = LsuL1Plugin_logic_refill_free[4];
  assign when_LsuL1Plugin_l384_5 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[5]);
  assign when_LsuL1Plugin_l388_5 = LsuL1Plugin_logic_refill_free[5];
  assign when_LsuL1Plugin_l384_6 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[6]);
  assign when_LsuL1Plugin_l388_6 = LsuL1Plugin_logic_refill_free[6];
  assign when_LsuL1Plugin_l384_7 = (LsuL1Plugin_logic_refill_push_valid && LsuL1Plugin_logic_refill_free[7]);
  assign when_LsuL1Plugin_l388_7 = LsuL1Plugin_logic_refill_free[7];
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_0_0 = ((LsuL1Plugin_logic_refill_slots_0_valid && (! LsuL1Plugin_logic_refill_slots_0_cmdSent)) && (LsuL1Plugin_logic_refill_slots_0_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_1_0 = ((LsuL1Plugin_logic_refill_slots_1_valid && (! LsuL1Plugin_logic_refill_slots_1_cmdSent)) && (LsuL1Plugin_logic_refill_slots_1_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_2_0 = ((LsuL1Plugin_logic_refill_slots_2_valid && (! LsuL1Plugin_logic_refill_slots_2_cmdSent)) && (LsuL1Plugin_logic_refill_slots_2_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_3_0 = ((LsuL1Plugin_logic_refill_slots_3_valid && (! LsuL1Plugin_logic_refill_slots_3_cmdSent)) && (LsuL1Plugin_logic_refill_slots_3_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_4_0 = ((LsuL1Plugin_logic_refill_slots_4_valid && (! LsuL1Plugin_logic_refill_slots_4_cmdSent)) && (LsuL1Plugin_logic_refill_slots_4_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_5_0 = ((LsuL1Plugin_logic_refill_slots_5_valid && (! LsuL1Plugin_logic_refill_slots_5_cmdSent)) && (LsuL1Plugin_logic_refill_slots_5_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_6_0 = ((LsuL1Plugin_logic_refill_slots_6_valid && (! LsuL1Plugin_logic_refill_slots_6_cmdSent)) && (LsuL1Plugin_logic_refill_slots_6_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_7_0 = ((LsuL1Plugin_logic_refill_slots_7_valid && (! LsuL1Plugin_logic_refill_slots_7_cmdSent)) && (LsuL1Plugin_logic_refill_slots_7_victim == 8'h0));
  assign LsuL1Plugin_logic_refill_read_arbiter_hits = {LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_7_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_6_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_5_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_4_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_3_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_2_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_1_0,LsuL1Plugin_logic_refill_read_arbiter_slotsWithId_0_0};
  assign LsuL1Plugin_logic_refill_read_arbiter_hit = (|LsuL1Plugin_logic_refill_read_arbiter_hits);
  always @(*) begin
    LsuL1Plugin_logic_refill_read_arbiter_oh = (LsuL1Plugin_logic_refill_read_arbiter_hits & {(({_zz_LsuL1Plugin_logic_refill_read_arbiter_oh,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_1,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_3,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_4,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_6,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_7,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_8} & LsuL1Plugin_logic_refill_slots_7_priority) == 7'h0),(({_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_9,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_11,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_12,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_14,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_15,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_17,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_18} & LsuL1Plugin_logic_refill_slots_6_priority) == 7'h0),((_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_19 & LsuL1Plugin_logic_refill_slots_5_priority) == 7'h0),(_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_29 == _zz_LsuL1Plugin_logic_refill_read_arbiter_oh_38),_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_39,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_49,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_61,_zz_LsuL1Plugin_logic_refill_read_arbiter_oh_69});
    if(when_LsuL1Plugin_l305) begin
      LsuL1Plugin_logic_refill_read_arbiter_oh = LsuL1Plugin_logic_refill_read_arbiter_lock;
    end
  end

  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel = LsuL1Plugin_logic_refill_read_arbiter_oh[1];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_1 = LsuL1Plugin_logic_refill_read_arbiter_oh[2];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_2 = LsuL1Plugin_logic_refill_read_arbiter_oh[3];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_3 = LsuL1Plugin_logic_refill_read_arbiter_oh[4];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_4 = LsuL1Plugin_logic_refill_read_arbiter_oh[5];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_5 = LsuL1Plugin_logic_refill_read_arbiter_oh[6];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_6 = LsuL1Plugin_logic_refill_read_arbiter_oh[7];
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_7 = (((_zz_LsuL1Plugin_logic_refill_read_arbiter_sel || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_2) || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_4) || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_6);
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_8 = (((_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_1 || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_2) || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_5) || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_6);
  assign _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_9 = (((_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_3 || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_4) || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_5) || _zz_LsuL1Plugin_logic_refill_read_arbiter_sel_6);
  assign LsuL1Plugin_logic_refill_read_arbiter_sel = {_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_9,_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_8,_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_7};
  assign when_LsuL1Plugin_l305 = (|LsuL1Plugin_logic_refill_read_arbiter_lock);
  assign LsuL1Plugin_logic_bus_read_cmd_fire = (LsuL1Plugin_logic_bus_read_cmd_valid && LsuL1Plugin_logic_bus_read_cmd_ready);
  assign LsuL1Plugin_logic_refill_read_cmdAddress = {_zz_LsuL1Plugin_logic_refill_read_cmdAddress,6'h0};
  assign LsuL1Plugin_logic_bus_read_cmd_valid = LsuL1Plugin_logic_refill_read_arbiter_hit;
  assign LsuL1Plugin_logic_bus_read_cmd_payload_id = LsuL1Plugin_logic_refill_read_arbiter_sel;
  assign LsuL1Plugin_logic_bus_read_cmd_payload_address = LsuL1Plugin_logic_refill_read_cmdAddress;
  assign LsuL1Plugin_logic_refill_read_rspAddress = _zz_LsuL1Plugin_logic_refill_read_rspAddress;
  assign LsuL1Plugin_logic_refill_read_way = _zz_LsuL1Plugin_logic_refill_read_way;
  assign LsuL1Plugin_logic_refill_read_rspWithData = 1'b1;
  always @(*) begin
    LsuL1Plugin_logic_refill_read_writeReservation_take = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      LsuL1Plugin_logic_refill_read_writeReservation_take = 1'b1;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_refill_read_bankWriteNotif[0] = ((LsuL1Plugin_logic_bus_read_rsp_valid && LsuL1Plugin_logic_refill_read_rspWithData) && (LsuL1Plugin_logic_refill_read_way == 1'b0));
    LsuL1Plugin_logic_refill_read_bankWriteNotif[1] = ((LsuL1Plugin_logic_bus_read_rsp_valid && LsuL1Plugin_logic_refill_read_rspWithData) && (LsuL1Plugin_logic_refill_read_way == 1'b1));
  end

  always @(*) begin
    LsuL1Plugin_logic_banksWrite_mask[0] = LsuL1Plugin_logic_refill_read_bankWriteNotif[0];
    LsuL1Plugin_logic_banksWrite_mask[1] = LsuL1Plugin_logic_refill_read_bankWriteNotif[1];
    if(LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win) begin
      if(when_LsuL1Plugin_l942) begin
        LsuL1Plugin_logic_banksWrite_mask[0] = ((1'b0 == LsuL1Plugin_logic_lsu_ctrl_wayId) && LsuL1Plugin_logic_lsu_ctrl_doWrite);
      end
      if(when_LsuL1Plugin_l942_1) begin
        LsuL1Plugin_logic_banksWrite_mask[1] = ((1'b1 == LsuL1Plugin_logic_lsu_ctrl_wayId) && LsuL1Plugin_logic_lsu_ctrl_doWrite);
      end
    end
    if(LsuL1Plugin_logic_initializerMem_busy) begin
      LsuL1Plugin_logic_banksWrite_mask = 2'b11;
    end
  end

  assign when_LsuL1Plugin_l455 = (LsuL1Plugin_logic_bus_read_rsp_valid && LsuL1Plugin_logic_bus_read_rsp_payload_error);
  always @(*) begin
    LsuL1Plugin_logic_refill_read_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_refill_read_fire = 1'b1;
      end
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_refill_read_reservation_take = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_refill_read_reservation_take = 1'b1;
      end
    end
  end

  assign LsuL1Plugin_logic_refill_read_faulty = (LsuL1Plugin_logic_refill_read_hadError || LsuL1Plugin_logic_bus_read_rsp_payload_error);
  always @(*) begin
    LsuL1Plugin_logic_refillCompletions = 8'h0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_refillCompletions[LsuL1Plugin_logic_bus_read_rsp_payload_id] = 1'b1;
      end
    end
  end

  assign LsuL1Plugin_logic_bus_read_rsp_ready = 1'b1;
  assign when_LsuL1Plugin_l468 = ((LsuL1Plugin_logic_refill_read_wordIndex == 3'b111) || (! LsuL1Plugin_logic_refill_read_rspWithData));
  assign LsuL1_REFILL_BUSY = {((! LsuL1Plugin_logic_refill_slots_7_loaded) && (! LsuL1Plugin_logic_refill_slots_7_loadedSet)),((! LsuL1Plugin_logic_refill_slots_6_loaded) && (! LsuL1Plugin_logic_refill_slots_6_loadedSet)),((! LsuL1Plugin_logic_refill_slots_5_loaded) && (! LsuL1Plugin_logic_refill_slots_5_loadedSet)),(_zz_LsuL1_REFILL_BUSY && _zz_LsuL1_REFILL_BUSY_1),_zz_LsuL1_REFILL_BUSY_2,_zz_LsuL1_REFILL_BUSY_3,((! LsuL1Plugin_logic_refill_slots_1_loaded) && (! LsuL1Plugin_logic_refill_slots_1_loadedSet)),((! LsuL1Plugin_logic_refill_slots_0_loaded) && (! LsuL1Plugin_logic_refill_slots_0_loadedSet))};
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_0_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
          LsuL1Plugin_logic_writeback_slots_0_fire = 1'b1;
        end
        3'b001 : begin
        end
        3'b010 : begin
        end
        3'b011 : begin
        end
        3'b100 : begin
        end
        3'b101 : begin
        end
        3'b110 : begin
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_0_timer_done = (LsuL1Plugin_logic_writeback_slots_0_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535 = ((LsuL1Plugin_logic_writeback_slots_0_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_0_fire || (! LsuL1Plugin_logic_writeback_slots_0_busy)));
  assign LsuL1Plugin_logic_writeback_slots_0_free = (! LsuL1Plugin_logic_writeback_slots_0_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_1_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
          LsuL1Plugin_logic_writeback_slots_1_fire = 1'b1;
        end
        3'b010 : begin
        end
        3'b011 : begin
        end
        3'b100 : begin
        end
        3'b101 : begin
        end
        3'b110 : begin
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_1_timer_done = (LsuL1Plugin_logic_writeback_slots_1_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_1 = ((LsuL1Plugin_logic_writeback_slots_1_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_1_fire || (! LsuL1Plugin_logic_writeback_slots_1_busy)));
  assign LsuL1Plugin_logic_writeback_slots_1_free = (! LsuL1Plugin_logic_writeback_slots_1_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_2_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
        end
        3'b010 : begin
          LsuL1Plugin_logic_writeback_slots_2_fire = 1'b1;
        end
        3'b011 : begin
        end
        3'b100 : begin
        end
        3'b101 : begin
        end
        3'b110 : begin
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_2_timer_done = (LsuL1Plugin_logic_writeback_slots_2_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_2 = ((LsuL1Plugin_logic_writeback_slots_2_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_2_fire || (! LsuL1Plugin_logic_writeback_slots_2_busy)));
  assign LsuL1Plugin_logic_writeback_slots_2_free = (! LsuL1Plugin_logic_writeback_slots_2_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_3_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
        end
        3'b010 : begin
        end
        3'b011 : begin
          LsuL1Plugin_logic_writeback_slots_3_fire = 1'b1;
        end
        3'b100 : begin
        end
        3'b101 : begin
        end
        3'b110 : begin
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_3_timer_done = (LsuL1Plugin_logic_writeback_slots_3_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_3 = ((LsuL1Plugin_logic_writeback_slots_3_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_3_fire || (! LsuL1Plugin_logic_writeback_slots_3_busy)));
  assign LsuL1Plugin_logic_writeback_slots_3_free = (! LsuL1Plugin_logic_writeback_slots_3_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_4_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
        end
        3'b010 : begin
        end
        3'b011 : begin
        end
        3'b100 : begin
          LsuL1Plugin_logic_writeback_slots_4_fire = 1'b1;
        end
        3'b101 : begin
        end
        3'b110 : begin
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_4_timer_done = (LsuL1Plugin_logic_writeback_slots_4_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_4 = ((LsuL1Plugin_logic_writeback_slots_4_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_4_fire || (! LsuL1Plugin_logic_writeback_slots_4_busy)));
  assign LsuL1Plugin_logic_writeback_slots_4_free = (! LsuL1Plugin_logic_writeback_slots_4_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_5_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
        end
        3'b010 : begin
        end
        3'b011 : begin
        end
        3'b100 : begin
        end
        3'b101 : begin
          LsuL1Plugin_logic_writeback_slots_5_fire = 1'b1;
        end
        3'b110 : begin
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_5_timer_done = (LsuL1Plugin_logic_writeback_slots_5_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_5 = ((LsuL1Plugin_logic_writeback_slots_5_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_5_fire || (! LsuL1Plugin_logic_writeback_slots_5_busy)));
  assign LsuL1Plugin_logic_writeback_slots_5_free = (! LsuL1Plugin_logic_writeback_slots_5_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_6_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
        end
        3'b010 : begin
        end
        3'b011 : begin
        end
        3'b100 : begin
        end
        3'b101 : begin
        end
        3'b110 : begin
          LsuL1Plugin_logic_writeback_slots_6_fire = 1'b1;
        end
        default : begin
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_6_timer_done = (LsuL1Plugin_logic_writeback_slots_6_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_6 = ((LsuL1Plugin_logic_writeback_slots_6_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_6_fire || (! LsuL1Plugin_logic_writeback_slots_6_busy)));
  assign LsuL1Plugin_logic_writeback_slots_6_free = (! LsuL1Plugin_logic_writeback_slots_6_valid);
  always @(*) begin
    LsuL1Plugin_logic_writeback_slots_7_fire = 1'b0;
    if(LsuL1Plugin_logic_bus_write_rsp_valid) begin
      case(LsuL1Plugin_logic_bus_write_rsp_payload_id)
        3'b000 : begin
        end
        3'b001 : begin
        end
        3'b010 : begin
        end
        3'b011 : begin
        end
        3'b100 : begin
        end
        3'b101 : begin
        end
        3'b110 : begin
        end
        default : begin
          LsuL1Plugin_logic_writeback_slots_7_fire = 1'b1;
        end
      endcase
    end
  end

  assign LsuL1Plugin_logic_writeback_slots_7_timer_done = (LsuL1Plugin_logic_writeback_slots_7_timer_counter == 1'b1);
  assign when_LsuL1Plugin_l535_7 = ((LsuL1Plugin_logic_writeback_slots_7_timer_done && (! LsuL1Plugin_logic_slotsFreeze)) && (LsuL1Plugin_logic_writeback_slots_7_fire || (! LsuL1Plugin_logic_writeback_slots_7_busy)));
  assign LsuL1Plugin_logic_writeback_slots_7_free = (! LsuL1Plugin_logic_writeback_slots_7_valid);
  assign LsuL1_WRITEBACK_BUSY = {LsuL1Plugin_logic_writeback_slots_7_valid,LsuL1Plugin_logic_writeback_slots_6_valid,LsuL1Plugin_logic_writeback_slots_5_valid,LsuL1Plugin_logic_writeback_slots_4_valid,LsuL1Plugin_logic_writeback_slots_3_valid,LsuL1Plugin_logic_writeback_slots_2_valid,LsuL1Plugin_logic_writeback_slots_1_valid,LsuL1Plugin_logic_writeback_slots_0_valid};
  assign LsuL1Plugin_logic_writebackBusy = (|{LsuL1Plugin_logic_writeback_slots_7_valid,LsuL1Plugin_logic_writeback_slots_6_valid,LsuL1Plugin_logic_writeback_slots_5_valid,LsuL1Plugin_logic_writeback_slots_4_valid,LsuL1Plugin_logic_writeback_slots_3_valid,LsuL1Plugin_logic_writeback_slots_2_valid,LsuL1Plugin_logic_writeback_slots_1_valid,LsuL1Plugin_logic_writeback_slots_0_valid});
  assign _zz_LsuL1Plugin_logic_writeback_free = {LsuL1Plugin_logic_writeback_slots_7_free,LsuL1Plugin_logic_writeback_slots_6_free,LsuL1Plugin_logic_writeback_slots_5_free,LsuL1Plugin_logic_writeback_slots_4_free,LsuL1Plugin_logic_writeback_slots_3_free,LsuL1Plugin_logic_writeback_slots_2_free,LsuL1Plugin_logic_writeback_slots_1_free,LsuL1Plugin_logic_writeback_slots_0_free};
  assign _zz_LsuL1Plugin_logic_writeback_free_1 = (_zz_LsuL1Plugin_logic_writeback_free & (~ _zz__zz_LsuL1Plugin_logic_writeback_free_1));
  assign LsuL1Plugin_logic_writeback_free = {_zz_LsuL1Plugin_logic_writeback_free_1[7],_zz_LsuL1Plugin_logic_writeback_free_1[6],_zz_LsuL1Plugin_logic_writeback_free_1[5],_zz_LsuL1Plugin_logic_writeback_free_1[4],_zz_LsuL1Plugin_logic_writeback_free_1[3],_zz_LsuL1Plugin_logic_writeback_free_1[2],_zz_LsuL1Plugin_logic_writeback_free_1[1],LsuL1Plugin_logic_writeback_slots_0_free};
  assign LsuL1Plugin_logic_writeback_full = (&{(! LsuL1Plugin_logic_writeback_slots_7_free),(! LsuL1Plugin_logic_writeback_slots_6_free),(! LsuL1Plugin_logic_writeback_slots_5_free),(! LsuL1Plugin_logic_writeback_slots_4_free),(! LsuL1Plugin_logic_writeback_slots_3_free),(! LsuL1Plugin_logic_writeback_slots_2_free),(! LsuL1Plugin_logic_writeback_slots_1_free),(! LsuL1Plugin_logic_writeback_slots_0_free)});
  always @(*) begin
    LsuL1Plugin_logic_writeback_push_valid = 1'b0;
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_writeback_push_valid = 1'b1;
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doRefill) begin
      LsuL1Plugin_logic_writeback_push_valid = LsuL1Plugin_logic_lsu_ctrl_refillWayNeedWriteback;
    end
    if(LsuL1Plugin_logic_lsu_ctrl_preventSideEffects) begin
      LsuL1Plugin_logic_writeback_push_valid = 1'b0;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_writeback_push_payload_address = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_writeback_push_payload_address = ({6'd0,{_zz_LsuL1Plugin_logic_waysWrite_tag_address,execute_ctrl4_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6]}} <<< 3'd6);
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doRefill) begin
      LsuL1Plugin_logic_writeback_push_payload_address = ({6'd0,{_zz_LsuL1Plugin_logic_writeback_push_payload_address,execute_ctrl4_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6]}} <<< 3'd6);
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_writeback_push_payload_way = 1'bx;
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_writeback_push_payload_way = LsuL1Plugin_logic_lsu_ctrl_needFlushSel;
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doRefill) begin
      LsuL1Plugin_logic_writeback_push_payload_way = LsuL1Plugin_logic_lsu_ctrl_targetWay;
    end
  end

  assign when_LsuL1Plugin_l561 = (LsuL1Plugin_logic_writeback_free[0] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566 = LsuL1Plugin_logic_writeback_free[0];
  assign when_LsuL1Plugin_l561_1 = (LsuL1Plugin_logic_writeback_free[1] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566_1 = LsuL1Plugin_logic_writeback_free[1];
  assign when_LsuL1Plugin_l561_2 = (LsuL1Plugin_logic_writeback_free[2] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566_2 = LsuL1Plugin_logic_writeback_free[2];
  assign when_LsuL1Plugin_l561_3 = (LsuL1Plugin_logic_writeback_free[3] && LsuL1Plugin_logic_writeback_push_valid);
