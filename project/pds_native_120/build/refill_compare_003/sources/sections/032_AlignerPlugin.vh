  assign AlignerPlugin_logic_maskGen_frontMasks_2 = 4'b1100;
  assign AlignerPlugin_logic_maskGen_frontMasks_3 = 4'b1000;
  assign AlignerPlugin_logic_maskGen_backMasks_0 = 4'b0001;
  assign AlignerPlugin_logic_maskGen_backMasks_1 = 4'b0011;
  assign AlignerPlugin_logic_maskGen_backMasks_2 = 4'b0111;
  assign AlignerPlugin_logic_maskGen_backMasks_3 = 4'b1111;
  assign fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK = (_zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK & ((! fetch_logic_ctrls_2_down_Prediction_WORD_JUMPED) ? 4'b1111 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK_2));
  assign fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_LAST = ((fetch_logic_ctrls_2_up_isValid && fetch_logic_ctrls_2_down_Prediction_WORD_JUMPED) ? _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_LAST : 4'b0000);
  assign AlignerPlugin_logic_slicesInstructions_0 = {AlignerPlugin_logic_slices_data_1,AlignerPlugin_logic_slices_data_0};
  assign AlignerPlugin_logic_slicesInstructions_1 = {AlignerPlugin_logic_slices_data_2,AlignerPlugin_logic_slices_data_1};
  assign AlignerPlugin_logic_slicesInstructions_2 = {AlignerPlugin_logic_slices_data_3,AlignerPlugin_logic_slices_data_2};
  assign AlignerPlugin_logic_slicesInstructions_3 = {AlignerPlugin_logic_slices_data_4,AlignerPlugin_logic_slices_data_3};
  assign AlignerPlugin_logic_slicesInstructions_4 = {AlignerPlugin_logic_slices_data_5,AlignerPlugin_logic_slices_data_4};
  assign AlignerPlugin_logic_slicesInstructions_5 = {AlignerPlugin_logic_slices_data_6,AlignerPlugin_logic_slices_data_5};
  assign AlignerPlugin_logic_slicesInstructions_6 = {AlignerPlugin_logic_slices_data_7,AlignerPlugin_logic_slices_data_6};
  assign AlignerPlugin_logic_slicesInstructions_7 = {16'd0, AlignerPlugin_logic_slices_data_7};
  always @(*) begin
    AlignerPlugin_logic_scanners_0_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_0_usageMask[0] = AlignerPlugin_logic_scanners_0_checker_0_required;
    AlignerPlugin_logic_scanners_0_usageMask[1] = AlignerPlugin_logic_scanners_0_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_0_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_0_checker_0_last = (AlignerPlugin_logic_slices_data_0[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_0_checker_0_redo = ((AlignerPlugin_logic_scanners_0_checker_0_required && AlignerPlugin_logic_slices_last[0]) && (! AlignerPlugin_logic_scanners_0_checker_0_last));
  assign AlignerPlugin_logic_scanners_0_checker_0_present = AlignerPlugin_logic_slices_mask[0];
  assign AlignerPlugin_logic_scanners_0_checker_0_valid = AlignerPlugin_logic_scanners_0_checker_0_present;
  assign AlignerPlugin_logic_scanners_0_checker_1_required = (AlignerPlugin_logic_slices_data_0[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_0_checker_1_last = (AlignerPlugin_logic_slices_data_0[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_0_checker_1_redo = ((AlignerPlugin_logic_scanners_0_checker_1_required && AlignerPlugin_logic_slices_last[1]) && (! AlignerPlugin_logic_scanners_0_checker_1_last));
  assign AlignerPlugin_logic_scanners_0_checker_1_present = AlignerPlugin_logic_slices_mask[1];
  assign AlignerPlugin_logic_scanners_0_checker_1_valid = (AlignerPlugin_logic_scanners_0_checker_1_present || (! AlignerPlugin_logic_scanners_0_checker_1_required));
  assign AlignerPlugin_logic_scanners_0_redo = (|{AlignerPlugin_logic_scanners_0_checker_1_redo,AlignerPlugin_logic_scanners_0_checker_0_redo});
  assign AlignerPlugin_logic_scanners_0_valid = (AlignerPlugin_logic_scanners_0_checker_0_valid && ((&AlignerPlugin_logic_scanners_0_checker_1_valid) || (|{AlignerPlugin_logic_scanners_0_checker_1_redo,AlignerPlugin_logic_scanners_0_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_1_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_1_usageMask[1] = AlignerPlugin_logic_scanners_1_checker_0_required;
    AlignerPlugin_logic_scanners_1_usageMask[2] = AlignerPlugin_logic_scanners_1_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_1_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_1_checker_0_last = (AlignerPlugin_logic_slices_data_1[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_1_checker_0_redo = ((AlignerPlugin_logic_scanners_1_checker_0_required && AlignerPlugin_logic_slices_last[1]) && (! AlignerPlugin_logic_scanners_1_checker_0_last));
  assign AlignerPlugin_logic_scanners_1_checker_0_present = AlignerPlugin_logic_slices_mask[1];
  assign AlignerPlugin_logic_scanners_1_checker_0_valid = AlignerPlugin_logic_scanners_1_checker_0_present;
  assign AlignerPlugin_logic_scanners_1_checker_1_required = (AlignerPlugin_logic_slices_data_1[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_1_checker_1_last = (AlignerPlugin_logic_slices_data_1[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_1_checker_1_redo = ((AlignerPlugin_logic_scanners_1_checker_1_required && AlignerPlugin_logic_slices_last[2]) && (! AlignerPlugin_logic_scanners_1_checker_1_last));
  assign AlignerPlugin_logic_scanners_1_checker_1_present = AlignerPlugin_logic_slices_mask[2];
  assign AlignerPlugin_logic_scanners_1_checker_1_valid = (AlignerPlugin_logic_scanners_1_checker_1_present || (! AlignerPlugin_logic_scanners_1_checker_1_required));
  assign AlignerPlugin_logic_scanners_1_redo = (|{AlignerPlugin_logic_scanners_1_checker_1_redo,AlignerPlugin_logic_scanners_1_checker_0_redo});
  assign AlignerPlugin_logic_scanners_1_valid = (AlignerPlugin_logic_scanners_1_checker_0_valid && ((&AlignerPlugin_logic_scanners_1_checker_1_valid) || (|{AlignerPlugin_logic_scanners_1_checker_1_redo,AlignerPlugin_logic_scanners_1_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_2_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_2_usageMask[2] = AlignerPlugin_logic_scanners_2_checker_0_required;
    AlignerPlugin_logic_scanners_2_usageMask[3] = AlignerPlugin_logic_scanners_2_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_2_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_2_checker_0_last = (AlignerPlugin_logic_slices_data_2[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_2_checker_0_redo = ((AlignerPlugin_logic_scanners_2_checker_0_required && AlignerPlugin_logic_slices_last[2]) && (! AlignerPlugin_logic_scanners_2_checker_0_last));
  assign AlignerPlugin_logic_scanners_2_checker_0_present = AlignerPlugin_logic_slices_mask[2];
  assign AlignerPlugin_logic_scanners_2_checker_0_valid = AlignerPlugin_logic_scanners_2_checker_0_present;
  assign AlignerPlugin_logic_scanners_2_checker_1_required = (AlignerPlugin_logic_slices_data_2[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_2_checker_1_last = (AlignerPlugin_logic_slices_data_2[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_2_checker_1_redo = ((AlignerPlugin_logic_scanners_2_checker_1_required && AlignerPlugin_logic_slices_last[3]) && (! AlignerPlugin_logic_scanners_2_checker_1_last));
  assign AlignerPlugin_logic_scanners_2_checker_1_present = AlignerPlugin_logic_slices_mask[3];
  assign AlignerPlugin_logic_scanners_2_checker_1_valid = (AlignerPlugin_logic_scanners_2_checker_1_present || (! AlignerPlugin_logic_scanners_2_checker_1_required));
  assign AlignerPlugin_logic_scanners_2_redo = (|{AlignerPlugin_logic_scanners_2_checker_1_redo,AlignerPlugin_logic_scanners_2_checker_0_redo});
  assign AlignerPlugin_logic_scanners_2_valid = (AlignerPlugin_logic_scanners_2_checker_0_valid && ((&AlignerPlugin_logic_scanners_2_checker_1_valid) || (|{AlignerPlugin_logic_scanners_2_checker_1_redo,AlignerPlugin_logic_scanners_2_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_3_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_3_usageMask[3] = AlignerPlugin_logic_scanners_3_checker_0_required;
    AlignerPlugin_logic_scanners_3_usageMask[4] = AlignerPlugin_logic_scanners_3_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_3_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_3_checker_0_last = (AlignerPlugin_logic_slices_data_3[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_3_checker_0_redo = ((AlignerPlugin_logic_scanners_3_checker_0_required && AlignerPlugin_logic_slices_last[3]) && (! AlignerPlugin_logic_scanners_3_checker_0_last));
  assign AlignerPlugin_logic_scanners_3_checker_0_present = AlignerPlugin_logic_slices_mask[3];
  assign AlignerPlugin_logic_scanners_3_checker_0_valid = AlignerPlugin_logic_scanners_3_checker_0_present;
  assign AlignerPlugin_logic_scanners_3_checker_1_required = (AlignerPlugin_logic_slices_data_3[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_3_checker_1_last = (AlignerPlugin_logic_slices_data_3[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_3_checker_1_redo = ((AlignerPlugin_logic_scanners_3_checker_1_required && AlignerPlugin_logic_slices_last[4]) && (! AlignerPlugin_logic_scanners_3_checker_1_last));
  assign AlignerPlugin_logic_scanners_3_checker_1_present = AlignerPlugin_logic_slices_mask[4];
  assign AlignerPlugin_logic_scanners_3_checker_1_valid = (AlignerPlugin_logic_scanners_3_checker_1_present || (! AlignerPlugin_logic_scanners_3_checker_1_required));
  assign AlignerPlugin_logic_scanners_3_redo = (|{AlignerPlugin_logic_scanners_3_checker_1_redo,AlignerPlugin_logic_scanners_3_checker_0_redo});
  assign AlignerPlugin_logic_scanners_3_valid = (AlignerPlugin_logic_scanners_3_checker_0_valid && ((&AlignerPlugin_logic_scanners_3_checker_1_valid) || (|{AlignerPlugin_logic_scanners_3_checker_1_redo,AlignerPlugin_logic_scanners_3_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_4_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_4_usageMask[4] = AlignerPlugin_logic_scanners_4_checker_0_required;
    AlignerPlugin_logic_scanners_4_usageMask[5] = AlignerPlugin_logic_scanners_4_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_4_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_4_checker_0_last = (AlignerPlugin_logic_slices_data_4[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_4_checker_0_redo = ((AlignerPlugin_logic_scanners_4_checker_0_required && AlignerPlugin_logic_slices_last[4]) && (! AlignerPlugin_logic_scanners_4_checker_0_last));
  assign AlignerPlugin_logic_scanners_4_checker_0_present = AlignerPlugin_logic_slices_mask[4];
  assign AlignerPlugin_logic_scanners_4_checker_0_valid = AlignerPlugin_logic_scanners_4_checker_0_present;
  assign AlignerPlugin_logic_scanners_4_checker_1_required = (AlignerPlugin_logic_slices_data_4[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_4_checker_1_last = (AlignerPlugin_logic_slices_data_4[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_4_checker_1_redo = ((AlignerPlugin_logic_scanners_4_checker_1_required && AlignerPlugin_logic_slices_last[5]) && (! AlignerPlugin_logic_scanners_4_checker_1_last));
  assign AlignerPlugin_logic_scanners_4_checker_1_present = AlignerPlugin_logic_slices_mask[5];
  assign AlignerPlugin_logic_scanners_4_checker_1_valid = (AlignerPlugin_logic_scanners_4_checker_1_present || (! AlignerPlugin_logic_scanners_4_checker_1_required));
  assign AlignerPlugin_logic_scanners_4_redo = (|{AlignerPlugin_logic_scanners_4_checker_1_redo,AlignerPlugin_logic_scanners_4_checker_0_redo});
  assign AlignerPlugin_logic_scanners_4_valid = (AlignerPlugin_logic_scanners_4_checker_0_valid && ((&AlignerPlugin_logic_scanners_4_checker_1_valid) || (|{AlignerPlugin_logic_scanners_4_checker_1_redo,AlignerPlugin_logic_scanners_4_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_5_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_5_usageMask[5] = AlignerPlugin_logic_scanners_5_checker_0_required;
    AlignerPlugin_logic_scanners_5_usageMask[6] = AlignerPlugin_logic_scanners_5_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_5_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_5_checker_0_last = (AlignerPlugin_logic_slices_data_5[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_5_checker_0_redo = ((AlignerPlugin_logic_scanners_5_checker_0_required && AlignerPlugin_logic_slices_last[5]) && (! AlignerPlugin_logic_scanners_5_checker_0_last));
  assign AlignerPlugin_logic_scanners_5_checker_0_present = AlignerPlugin_logic_slices_mask[5];
  assign AlignerPlugin_logic_scanners_5_checker_0_valid = AlignerPlugin_logic_scanners_5_checker_0_present;
  assign AlignerPlugin_logic_scanners_5_checker_1_required = (AlignerPlugin_logic_slices_data_5[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_5_checker_1_last = (AlignerPlugin_logic_slices_data_5[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_5_checker_1_redo = ((AlignerPlugin_logic_scanners_5_checker_1_required && AlignerPlugin_logic_slices_last[6]) && (! AlignerPlugin_logic_scanners_5_checker_1_last));
  assign AlignerPlugin_logic_scanners_5_checker_1_present = AlignerPlugin_logic_slices_mask[6];
  assign AlignerPlugin_logic_scanners_5_checker_1_valid = (AlignerPlugin_logic_scanners_5_checker_1_present || (! AlignerPlugin_logic_scanners_5_checker_1_required));
  assign AlignerPlugin_logic_scanners_5_redo = (|{AlignerPlugin_logic_scanners_5_checker_1_redo,AlignerPlugin_logic_scanners_5_checker_0_redo});
  assign AlignerPlugin_logic_scanners_5_valid = (AlignerPlugin_logic_scanners_5_checker_0_valid && ((&AlignerPlugin_logic_scanners_5_checker_1_valid) || (|{AlignerPlugin_logic_scanners_5_checker_1_redo,AlignerPlugin_logic_scanners_5_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_6_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_6_usageMask[6] = AlignerPlugin_logic_scanners_6_checker_0_required;
    AlignerPlugin_logic_scanners_6_usageMask[7] = AlignerPlugin_logic_scanners_6_checker_1_required;
  end

  assign AlignerPlugin_logic_scanners_6_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_6_checker_0_last = (AlignerPlugin_logic_slices_data_6[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_6_checker_0_redo = ((AlignerPlugin_logic_scanners_6_checker_0_required && AlignerPlugin_logic_slices_last[6]) && (! AlignerPlugin_logic_scanners_6_checker_0_last));
  assign AlignerPlugin_logic_scanners_6_checker_0_present = AlignerPlugin_logic_slices_mask[6];
  assign AlignerPlugin_logic_scanners_6_checker_0_valid = AlignerPlugin_logic_scanners_6_checker_0_present;
  assign AlignerPlugin_logic_scanners_6_checker_1_required = (AlignerPlugin_logic_slices_data_6[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_6_checker_1_last = (AlignerPlugin_logic_slices_data_6[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_6_checker_1_redo = ((AlignerPlugin_logic_scanners_6_checker_1_required && AlignerPlugin_logic_slices_last[7]) && (! AlignerPlugin_logic_scanners_6_checker_1_last));
  assign AlignerPlugin_logic_scanners_6_checker_1_present = AlignerPlugin_logic_slices_mask[7];
  assign AlignerPlugin_logic_scanners_6_checker_1_valid = (AlignerPlugin_logic_scanners_6_checker_1_present || (! AlignerPlugin_logic_scanners_6_checker_1_required));
  assign AlignerPlugin_logic_scanners_6_redo = (|{AlignerPlugin_logic_scanners_6_checker_1_redo,AlignerPlugin_logic_scanners_6_checker_0_redo});
  assign AlignerPlugin_logic_scanners_6_valid = (AlignerPlugin_logic_scanners_6_checker_0_valid && ((&AlignerPlugin_logic_scanners_6_checker_1_valid) || (|{AlignerPlugin_logic_scanners_6_checker_1_redo,AlignerPlugin_logic_scanners_6_checker_0_redo})));
  always @(*) begin
    AlignerPlugin_logic_scanners_7_usageMask = 8'h0;
    AlignerPlugin_logic_scanners_7_usageMask[7] = AlignerPlugin_logic_scanners_7_checker_0_required;
  end

  assign AlignerPlugin_logic_scanners_7_checker_0_required = 1'b1;
  assign AlignerPlugin_logic_scanners_7_checker_0_last = (AlignerPlugin_logic_slices_data_7[1 : 0] != 2'b11);
  assign AlignerPlugin_logic_scanners_7_checker_0_redo = ((AlignerPlugin_logic_scanners_7_checker_0_required && AlignerPlugin_logic_slices_last[7]) && (! AlignerPlugin_logic_scanners_7_checker_0_last));
  assign AlignerPlugin_logic_scanners_7_checker_0_present = AlignerPlugin_logic_slices_mask[7];
  assign AlignerPlugin_logic_scanners_7_checker_0_valid = AlignerPlugin_logic_scanners_7_checker_0_present;
  assign AlignerPlugin_logic_scanners_7_checker_1_required = (AlignerPlugin_logic_slices_data_7[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_7_checker_1_last = (AlignerPlugin_logic_slices_data_7[1 : 0] == 2'b11);
  assign AlignerPlugin_logic_scanners_7_checker_1_redo = 1'b0;
  assign AlignerPlugin_logic_scanners_7_checker_1_present = 1'b0;
  assign AlignerPlugin_logic_scanners_7_checker_1_valid = (AlignerPlugin_logic_scanners_7_checker_1_present || (! AlignerPlugin_logic_scanners_7_checker_1_required));
  assign AlignerPlugin_logic_scanners_7_redo = (|{AlignerPlugin_logic_scanners_7_checker_1_redo,AlignerPlugin_logic_scanners_7_checker_0_redo});
  assign AlignerPlugin_logic_scanners_7_valid = (AlignerPlugin_logic_scanners_7_checker_0_valid && ((&AlignerPlugin_logic_scanners_7_checker_1_valid) || (|{AlignerPlugin_logic_scanners_7_checker_1_redo,AlignerPlugin_logic_scanners_7_checker_0_redo})));
  assign AlignerPlugin_logic_usedMask_0 = 8'h0;
  assign AlignerPlugin_logic_extractors_0_first = 1'b1;
  assign AlignerPlugin_logic_extractors_0_usableMask = {(AlignerPlugin_logic_scanners_7_valid && (! AlignerPlugin_logic_usedMask_0[7])),(AlignerPlugin_logic_scanners_6_valid && (! AlignerPlugin_logic_usedMask_0[6])),(AlignerPlugin_logic_scanners_5_valid && (! AlignerPlugin_logic_usedMask_0[5])),(AlignerPlugin_logic_scanners_4_valid && (! _zz_AlignerPlugin_logic_extractors_0_usableMask)),(AlignerPlugin_logic_scanners_3_valid && _zz_AlignerPlugin_logic_extractors_0_usableMask_1),_zz_AlignerPlugin_logic_extractors_0_usableMask_2,_zz_AlignerPlugin_logic_extractors_0_usableMask_3,_zz_AlignerPlugin_logic_extractors_0_usableMask_4};
  assign _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0 = AlignerPlugin_logic_extractors_0_usableMask;
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_0 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[0];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_1 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[1];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_2 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[2];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_3 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[3];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_4 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[4];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_5 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[5];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_6 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[6];
  assign AlignerPlugin_logic_extractors_0_usableMask_bools_7 = _zz_AlignerPlugin_logic_extractors_0_usableMask_bools_0[7];
  always @(*) begin
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[0] = (AlignerPlugin_logic_extractors_0_usableMask_bools_0 && (! 1'b0));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[1] = (AlignerPlugin_logic_extractors_0_usableMask_bools_1 && (! AlignerPlugin_logic_extractors_0_usableMask_bools_0));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[2] = (AlignerPlugin_logic_extractors_0_usableMask_bools_2 && (! AlignerPlugin_logic_extractors_0_usableMask_range_0_to_1));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[3] = (AlignerPlugin_logic_extractors_0_usableMask_bools_3 && (! AlignerPlugin_logic_extractors_0_usableMask_range_0_to_2));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[4] = (AlignerPlugin_logic_extractors_0_usableMask_bools_4 && (! AlignerPlugin_logic_extractors_0_usableMask_range_0_to_3));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[5] = (AlignerPlugin_logic_extractors_0_usableMask_bools_5 && (! (AlignerPlugin_logic_extractors_0_usableMask_bools_4 || AlignerPlugin_logic_extractors_0_usableMask_range_0_to_3)));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[6] = (AlignerPlugin_logic_extractors_0_usableMask_bools_6 && (! (AlignerPlugin_logic_extractors_0_usableMask_range_4_to_5 || AlignerPlugin_logic_extractors_0_usableMask_range_0_to_3)));
    _zz_AlignerPlugin_logic_extractors_0_slicesOh[7] = (AlignerPlugin_logic_extractors_0_usableMask_bools_7 && (! (AlignerPlugin_logic_extractors_0_usableMask_range_4_to_6 || AlignerPlugin_logic_extractors_0_usableMask_range_0_to_3)));
  end

  assign AlignerPlugin_logic_extractors_0_usableMask_range_0_to_1 = (|{AlignerPlugin_logic_extractors_0_usableMask_bools_1,AlignerPlugin_logic_extractors_0_usableMask_bools_0});
  assign AlignerPlugin_logic_extractors_0_usableMask_range_0_to_2 = (|{AlignerPlugin_logic_extractors_0_usableMask_bools_2,AlignerPlugin_logic_extractors_0_usableMask_bools_1,AlignerPlugin_logic_extractors_0_usableMask_bools_0});
  assign AlignerPlugin_logic_extractors_0_usableMask_range_0_to_3 = (|{AlignerPlugin_logic_extractors_0_usableMask_bools_3,AlignerPlugin_logic_extractors_0_usableMask_bools_2,AlignerPlugin_logic_extractors_0_usableMask_bools_1,AlignerPlugin_logic_extractors_0_usableMask_bools_0});
  assign AlignerPlugin_logic_extractors_0_usableMask_range_4_to_5 = (|{AlignerPlugin_logic_extractors_0_usableMask_bools_5,AlignerPlugin_logic_extractors_0_usableMask_bools_4});
  assign AlignerPlugin_logic_extractors_0_usableMask_range_4_to_6 = (|{AlignerPlugin_logic_extractors_0_usableMask_bools_6,AlignerPlugin_logic_extractors_0_usableMask_bools_5,AlignerPlugin_logic_extractors_0_usableMask_bools_4});
  assign AlignerPlugin_logic_extractors_0_slicesOh = _zz_AlignerPlugin_logic_extractors_0_slicesOh;
  assign _zz_AlignerPlugin_logic_extractors_0_redo = AlignerPlugin_logic_extractors_0_slicesOh[0];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_1 = AlignerPlugin_logic_extractors_0_slicesOh[1];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_2 = AlignerPlugin_logic_extractors_0_slicesOh[2];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_3 = AlignerPlugin_logic_extractors_0_slicesOh[3];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_4 = AlignerPlugin_logic_extractors_0_slicesOh[4];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_5 = AlignerPlugin_logic_extractors_0_slicesOh[5];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_6 = AlignerPlugin_logic_extractors_0_slicesOh[6];
  assign _zz_AlignerPlugin_logic_extractors_0_redo_7 = AlignerPlugin_logic_extractors_0_slicesOh[7];
  always @(*) begin
    AlignerPlugin_logic_extractors_0_redo = _zz_AlignerPlugin_logic_extractors_0_redo_8[0];
    if(when_AlignerPlugin_l160) begin
      AlignerPlugin_logic_extractors_0_redo = 1'b0;
    end
  end

  assign AlignerPlugin_logic_extractors_0_localMask = ((((_zz_AlignerPlugin_logic_extractors_0_redo ? {_zz_AlignerPlugin_logic_extractors_0_localMask,_zz_AlignerPlugin_logic_extractors_0_localMask_1} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_0_redo_1 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_2,_zz_AlignerPlugin_logic_extractors_0_localMask_3} : 2'b00)) | ((_zz_AlignerPlugin_logic_extractors_0_redo_2 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_4,_zz_AlignerPlugin_logic_extractors_0_localMask_5} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_0_redo_3 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_6,_zz_AlignerPlugin_logic_extractors_0_localMask_7} : 2'b00))) | (((_zz_AlignerPlugin_logic_extractors_0_redo_4 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_8,_zz_AlignerPlugin_logic_extractors_0_localMask_9} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_0_redo_5 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_10,_zz_AlignerPlugin_logic_extractors_0_localMask_11} : 2'b00)) | ((_zz_AlignerPlugin_logic_extractors_0_redo_6 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_12,_zz_AlignerPlugin_logic_extractors_0_localMask_13} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_0_redo_7 ? {_zz_AlignerPlugin_logic_extractors_0_localMask_14,_zz_AlignerPlugin_logic_extractors_0_localMask_15} : 2'b00))));
  assign AlignerPlugin_logic_extractors_0_usageMask = ((((_zz_AlignerPlugin_logic_extractors_0_redo ? AlignerPlugin_logic_scanners_0_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_0_redo_1 ? AlignerPlugin_logic_scanners_1_usageMask : 8'h0)) | ((_zz_AlignerPlugin_logic_extractors_0_redo_2 ? AlignerPlugin_logic_scanners_2_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_0_redo_3 ? AlignerPlugin_logic_scanners_3_usageMask : 8'h0))) | (((_zz_AlignerPlugin_logic_extractors_0_redo_4 ? AlignerPlugin_logic_scanners_4_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_0_redo_5 ? AlignerPlugin_logic_scanners_5_usageMask : 8'h0)) | ((_zz_AlignerPlugin_logic_extractors_0_redo_6 ? AlignerPlugin_logic_scanners_6_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_0_redo_7 ? AlignerPlugin_logic_scanners_7_usageMask : 8'h0))));
  assign AlignerPlugin_logic_usedMask_1 = (AlignerPlugin_logic_usedMask_0 | AlignerPlugin_logic_extractors_0_usageMask);
  always @(*) begin
    AlignerPlugin_logic_extractors_0_valid = (|AlignerPlugin_logic_extractors_0_slicesOh);
    if(when_AlignerPlugin_l160) begin
      AlignerPlugin_logic_extractors_0_valid = 1'b0;
    end
    if(when_AlignerPlugin_l240) begin
      if(when_AlignerPlugin_l241) begin
        AlignerPlugin_logic_extractors_0_valid = 1'b0;
      end
    end
  end

  assign when_AlignerPlugin_l160 = (AlignerPlugin_api_haltIt || (AlignerPlugin_api_singleFetch && (! AlignerPlugin_logic_extractors_0_first)));
  assign AlignerPlugin_logic_extractors_1_first = 1'b0;
  assign AlignerPlugin_logic_extractors_1_usableMask = {(AlignerPlugin_logic_scanners_7_valid && (! AlignerPlugin_logic_usedMask_1[7])),(AlignerPlugin_logic_scanners_6_valid && (! AlignerPlugin_logic_usedMask_1[6])),(AlignerPlugin_logic_scanners_5_valid && (! AlignerPlugin_logic_usedMask_1[5])),(AlignerPlugin_logic_scanners_4_valid && (! _zz_AlignerPlugin_logic_extractors_1_usableMask)),(AlignerPlugin_logic_scanners_3_valid && _zz_AlignerPlugin_logic_extractors_1_usableMask_1),_zz_AlignerPlugin_logic_extractors_1_usableMask_2,_zz_AlignerPlugin_logic_extractors_1_usableMask_3};
  assign _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0 = AlignerPlugin_logic_extractors_1_usableMask;
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_0 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[0];
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_1 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[1];
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_2 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[2];
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_3 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[3];
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_4 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[4];
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_5 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[5];
  assign AlignerPlugin_logic_extractors_1_usableMask_bools_6 = _zz_AlignerPlugin_logic_extractors_1_usableMask_bools_0[6];
  always @(*) begin
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[0] = (AlignerPlugin_logic_extractors_1_usableMask_bools_0 && (! 1'b0));
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[1] = (AlignerPlugin_logic_extractors_1_usableMask_bools_1 && (! AlignerPlugin_logic_extractors_1_usableMask_bools_0));
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[2] = (AlignerPlugin_logic_extractors_1_usableMask_bools_2 && (! AlignerPlugin_logic_extractors_1_usableMask_range_0_to_1));
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[3] = (AlignerPlugin_logic_extractors_1_usableMask_bools_3 && (! AlignerPlugin_logic_extractors_1_usableMask_range_0_to_2));
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[4] = (AlignerPlugin_logic_extractors_1_usableMask_bools_4 && (! AlignerPlugin_logic_extractors_1_usableMask_range_0_to_3));
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[5] = (AlignerPlugin_logic_extractors_1_usableMask_bools_5 && (! (AlignerPlugin_logic_extractors_1_usableMask_bools_4 || AlignerPlugin_logic_extractors_1_usableMask_range_0_to_3)));
    _zz_AlignerPlugin_logic_extractors_1_slicesOh[6] = (AlignerPlugin_logic_extractors_1_usableMask_bools_6 && (! (AlignerPlugin_logic_extractors_1_usableMask_range_4_to_5 || AlignerPlugin_logic_extractors_1_usableMask_range_0_to_3)));
  end

  assign AlignerPlugin_logic_extractors_1_usableMask_range_0_to_1 = (|{AlignerPlugin_logic_extractors_1_usableMask_bools_1,AlignerPlugin_logic_extractors_1_usableMask_bools_0});
  assign AlignerPlugin_logic_extractors_1_usableMask_range_0_to_2 = (|{AlignerPlugin_logic_extractors_1_usableMask_bools_2,AlignerPlugin_logic_extractors_1_usableMask_bools_1,AlignerPlugin_logic_extractors_1_usableMask_bools_0});
  assign AlignerPlugin_logic_extractors_1_usableMask_range_0_to_3 = (|{AlignerPlugin_logic_extractors_1_usableMask_bools_3,AlignerPlugin_logic_extractors_1_usableMask_bools_2,AlignerPlugin_logic_extractors_1_usableMask_bools_1,AlignerPlugin_logic_extractors_1_usableMask_bools_0});
  assign AlignerPlugin_logic_extractors_1_usableMask_range_4_to_5 = (|{AlignerPlugin_logic_extractors_1_usableMask_bools_5,AlignerPlugin_logic_extractors_1_usableMask_bools_4});
  assign AlignerPlugin_logic_extractors_1_slicesOh = _zz_AlignerPlugin_logic_extractors_1_slicesOh;
  assign _zz_AlignerPlugin_logic_extractors_1_redo = AlignerPlugin_logic_extractors_1_slicesOh[0];
  assign _zz_AlignerPlugin_logic_extractors_1_redo_1 = AlignerPlugin_logic_extractors_1_slicesOh[1];
  assign _zz_AlignerPlugin_logic_extractors_1_redo_2 = AlignerPlugin_logic_extractors_1_slicesOh[2];
  assign _zz_AlignerPlugin_logic_extractors_1_redo_3 = AlignerPlugin_logic_extractors_1_slicesOh[3];
  assign _zz_AlignerPlugin_logic_extractors_1_redo_4 = AlignerPlugin_logic_extractors_1_slicesOh[4];
  assign _zz_AlignerPlugin_logic_extractors_1_redo_5 = AlignerPlugin_logic_extractors_1_slicesOh[5];
  assign _zz_AlignerPlugin_logic_extractors_1_redo_6 = AlignerPlugin_logic_extractors_1_slicesOh[6];
  always @(*) begin
    AlignerPlugin_logic_extractors_1_redo = _zz_AlignerPlugin_logic_extractors_1_redo_7[0];
    if(when_AlignerPlugin_l160_1) begin
      AlignerPlugin_logic_extractors_1_redo = 1'b0;
    end
  end

  assign AlignerPlugin_logic_extractors_1_localMask = ((((_zz_AlignerPlugin_logic_extractors_1_redo ? {_zz_AlignerPlugin_logic_extractors_1_localMask,_zz_AlignerPlugin_logic_extractors_1_localMask_1} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_1_redo_1 ? {_zz_AlignerPlugin_logic_extractors_1_localMask_2,_zz_AlignerPlugin_logic_extractors_1_localMask_3} : 2'b00)) | ((_zz_AlignerPlugin_logic_extractors_1_redo_2 ? {_zz_AlignerPlugin_logic_extractors_1_localMask_4,_zz_AlignerPlugin_logic_extractors_1_localMask_5} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_1_redo_3 ? {_zz_AlignerPlugin_logic_extractors_1_localMask_6,_zz_AlignerPlugin_logic_extractors_1_localMask_7} : 2'b00))) | (((_zz_AlignerPlugin_logic_extractors_1_redo_4 ? {_zz_AlignerPlugin_logic_extractors_1_localMask_8,_zz_AlignerPlugin_logic_extractors_1_localMask_9} : 2'b00) | (_zz_AlignerPlugin_logic_extractors_1_redo_5 ? {_zz_AlignerPlugin_logic_extractors_1_localMask_10,_zz_AlignerPlugin_logic_extractors_1_localMask_11} : 2'b00)) | (_zz_AlignerPlugin_logic_extractors_1_redo_6 ? {AlignerPlugin_logic_scanners_7_checker_1_required,AlignerPlugin_logic_scanners_7_checker_0_required} : 2'b00)));
  assign AlignerPlugin_logic_extractors_1_usageMask = ((((_zz_AlignerPlugin_logic_extractors_1_redo ? AlignerPlugin_logic_scanners_1_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_1_redo_1 ? AlignerPlugin_logic_scanners_2_usageMask : 8'h0)) | ((_zz_AlignerPlugin_logic_extractors_1_redo_2 ? AlignerPlugin_logic_scanners_3_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_1_redo_3 ? AlignerPlugin_logic_scanners_4_usageMask : 8'h0))) | (((_zz_AlignerPlugin_logic_extractors_1_redo_4 ? AlignerPlugin_logic_scanners_5_usageMask : 8'h0) | (_zz_AlignerPlugin_logic_extractors_1_redo_5 ? AlignerPlugin_logic_scanners_6_usageMask : 8'h0)) | (_zz_AlignerPlugin_logic_extractors_1_redo_6 ? AlignerPlugin_logic_scanners_7_usageMask : 8'h0)));
  assign AlignerPlugin_logic_usedMask_2 = (AlignerPlugin_logic_usedMask_1 | AlignerPlugin_logic_extractors_1_usageMask);
  always @(*) begin
    AlignerPlugin_logic_extractors_1_valid = (|AlignerPlugin_logic_extractors_1_slicesOh);
    if(when_AlignerPlugin_l160_1) begin
      AlignerPlugin_logic_extractors_1_valid = 1'b0;
    end
    if(when_AlignerPlugin_l240) begin
      if(when_AlignerPlugin_l241_1) begin
        AlignerPlugin_logic_extractors_1_valid = 1'b0;
      end
    end
  end

  assign when_AlignerPlugin_l160_1 = (AlignerPlugin_api_haltIt || (AlignerPlugin_api_singleFetch && (! AlignerPlugin_logic_extractors_1_first)));
  assign when_AlignerPlugin_l171 = (decode_ctrls_0_up_isFiring && 1'b1);
  assign AlignerPlugin_logic_feeder_lanes_0_valid = AlignerPlugin_logic_extractors_0_valid;
  assign decode_ctrls_0_up_LANE_SEL_0 = AlignerPlugin_logic_feeder_lanes_0_valid;
  always @(*) begin
    decode_ctrls_0_up_Decode_INSTRUCTION_0 = AlignerPlugin_logic_extractors_0_ctx_instruction;
    if(AlignerPlugin_logic_feeder_lanes_0_isRvc) begin
      decode_ctrls_0_up_Decode_INSTRUCTION_0 = AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst;
    end
  end

  always @(*) begin
    decode_ctrls_0_up_Decode_DECOMPRESSION_FAULT_0 = 1'b0;
    if(AlignerPlugin_logic_feeder_lanes_0_isRvc) begin
      decode_ctrls_0_up_Decode_DECOMPRESSION_FAULT_0 = AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal;
    end
  end

  always @(*) begin
    decode_ctrls_0_up_Decode_INSTRUCTION_RAW_0 = AlignerPlugin_logic_extractors_0_ctx_instruction;
    if(AlignerPlugin_logic_feeder_lanes_0_isRvc) begin
      decode_ctrls_0_up_Decode_INSTRUCTION_RAW_0[31 : 16] = 16'h0;
    end
  end

  assign AlignerPlugin_logic_feeder_lanes_0_isRvc = (AlignerPlugin_logic_extractors_0_ctx_instruction[1 : 0] != 2'b11);
  always @(*) begin
    AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(switch_Rvc_l55)
      5'h0 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {2'b00,AlignerPlugin_logic_extractors_0_ctx_instruction[10 : 7],AlignerPlugin_logic_extractors_0_ctx_instruction[12 : 11],AlignerPlugin_logic_extractors_0_ctx_instruction[5],AlignerPlugin_logic_extractors_0_ctx_instruction[6],2'b00,5'h02,3'b000,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_1,7'h13};
      end
      5'h02 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_2,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,3'b010,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_1,7'h03};
      end
      5'h06 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_2[11 : 5],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_1,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,3'b010,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_2[4 : 0],7'h23};
      end
      5'h08 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],3'b000,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h13};
      end
      5'h09 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_7[20],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_7[10 : 1],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_7[11],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_7[19 : 12],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_19,7'h6f};
      end
      5'h0a : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4,5'h0,3'b000,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h13};
      end
      5'h0b : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = ((AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7] == 5'h02) ? {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_11,AlignerPlugin_logic_extractors_0_ctx_instruction[4 : 3],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_23,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_24,AlignerPlugin_logic_extractors_0_ctx_instruction[6],4'b0000,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],3'b000,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h13} : {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_25[31 : 12],AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h37});
      end
      5'h0c : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_26;
      end
      5'h0d : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_14[20],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_14[10 : 1],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_14[11],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_14[19 : 12],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_18,7'h6f};
      end
      5'h0e : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[12],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[10 : 5],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_18,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,3'b000,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[4 : 1],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[11],7'h63};
      end
      5'h0f : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[12],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[10 : 5],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_18,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,3'b001,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[4 : 1],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_17[11],7'h63};
      end
      5'h10 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {6'h0,AlignerPlugin_logic_extractors_0_ctx_instruction[12],AlignerPlugin_logic_extractors_0_ctx_instruction[6 : 2],AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],3'b001,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h13};
      end
      5'h12 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {4'b0000,AlignerPlugin_logic_extractors_0_ctx_instruction[3 : 2],AlignerPlugin_logic_extractors_0_ctx_instruction[12],AlignerPlugin_logic_extractors_0_ctx_instruction[6 : 4],2'b00,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_20,3'b010,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h03};
      end
      5'h14 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = ((AlignerPlugin_logic_extractors_0_ctx_instruction[12 : 2] == 11'h400) ? 32'h00100073 : ((AlignerPlugin_logic_extractors_0_ctx_instruction[6 : 2] == 5'h0) ? {12'h0,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],3'b000,(AlignerPlugin_logic_extractors_0_ctx_instruction[12] ? _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_19 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_18),7'h67} : {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_30,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_31,(_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_32 ? _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_33 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_18),3'b000,AlignerPlugin_logic_extractors_0_ctx_instruction[11 : 7],7'h33}));
      end
      5'h16 : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_34[11 : 5],AlignerPlugin_logic_extractors_0_ctx_instruction[6 : 2],_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_20,3'b010,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_35[4 : 0],7'h23};
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal = 1'b0;
    case(switch_Rvc_l55)
      5'h0 : begin
        if(when_Rvc_l59) begin
          AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal = 1'b1;
        end
      end
      5'h02 : begin
      end
      5'h06 : begin
      end
      5'h08 : begin
      end
      5'h09 : begin
      end
      5'h0a : begin
      end
      5'h0b : begin
        if(when_Rvc_l80) begin
          AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal = 1'b1;
        end
      end
      5'h0c : begin
      end
      5'h0d : begin
      end
      5'h0e : begin
      end
      5'h0f : begin
      end
      5'h10 : begin
      end
      5'h12 : begin
        if(when_Rvc_l101) begin
          AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal = 1'b1;
        end
      end
      5'h14 : begin
        if(when_Rvc_l114) begin
          AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal = 1'b1;
        end
      end
      5'h16 : begin
      end
      default : begin
        AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_illegal = 1'b1;
      end
    endcase
  end

  assign _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst = {2'b01,AlignerPlugin_logic_extractors_0_ctx_instruction[9 : 7]};
  assign _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_1 = {2'b01,AlignerPlugin_logic_extractors_0_ctx_instruction[4 : 2]};
  assign _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_2 = {5'h0,AlignerPlugin_logic_extractors_0_ctx_instruction[5],AlignerPlugin_logic_extractors_0_ctx_instruction[12 : 10],AlignerPlugin_logic_extractors_0_ctx_instruction[6],2'b00};
  assign _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3 = AlignerPlugin_logic_extractors_0_ctx_instruction[12];
  always @(*) begin
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[11] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[10] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[9] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[8] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[7] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[6] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[5] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_3;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4[4 : 0] = AlignerPlugin_logic_extractors_0_ctx_instruction[6 : 2];
  end

  assign _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5 = AlignerPlugin_logic_extractors_0_ctx_instruction[12];
  always @(*) begin
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[9] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[8] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[7] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[6] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[5] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[4] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[3] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[2] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[1] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
    _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_6[0] = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_5;
  end

