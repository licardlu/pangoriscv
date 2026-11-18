// Natural Mandarin, standard IMA ADPCM4 at12kHz; each sample repeats4 times.
// Legacy ROM filename is retained for synthesis-load gate compatibility.
module trash_voice_rom_player #(
    parameter ROM_FILE="../../extensions/business/application/assets/audio_rom/voice_pcm8.hex",
    parameter integer ROM_SAMPLES=118887
)(input wire clk,rst,request_valid,input wire [3:0] request_asset_id,
  input wire sample_ready,output wire sample_valid,output wire [15:0] sample_pcm,
  output wire sample_last,output reg busy);
    // Keep each inferred memory within one native 18K block. A single deep
    // ROM can infer cascaded DRM36K pairs whose identical lower halves PDS
    // merges, creating illegal COUTA fanout. Explicit banks use a fabric mux
    // and cannot require those dedicated cascade connections.
    localparam integer BANK_AW = 11;
    localparam integer BANK_SIZE = 1 << BANK_AW;
    localparam integer BANK_COUNT = (ROM_SAMPLES+BANK_SIZE-1)/BANK_SIZE;
    localparam integer ADDRESS_W = ROM_SAMPLES < 2 ? 1 : $clog2(ROM_SAMPLES);
    localparam integer BANK_SEL_W = BANK_COUNT < 2 ? 1 : $clog2(BANK_COUNT);
    reg [ADDRESS_W-1:0] address;
    reg [31:0] remaining;
    wire [7:0] bank_q [0:BANK_COUNT-1];
    reg [BANK_SEL_W-1:0] bank_select_q;
    wire [7:0] rom_q = bank_q[bank_select_q];
    genvar bank;
    generate for(bank=0;bank<BANK_COUNT;bank=bank+1) begin: voice_bank
        // Keep only the first 50 KiB in block ROM to reserve DRM for SD/JPEG.
        // ADS Synthesis User Guide section 5.18 defines both styles.  All
        // banks retain the same registered read and byte-for-byte PCM data.
        localparam ROM_STYLE = bank >= 25 ? "lut_rom" : "block_rom";
        (* syn_romstyle = ROM_STYLE *) reg [7:0] samples [0:BANK_SIZE-1];
        reg [7:0] data_q;
        // ADS requires literal filenames for readmemh, including the path.
        // Synthesis runs from yolo/sources, like the other ROM assets. The
        // simulation branch permits alternate ROM_FILE paths and fixtures;
        // both read the same independently verified byte-for-byte bank files.
        case (bank)
            0: begin: init_bank_00
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank00.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank00.hex"}, samples);
`endif
            end
            1: begin: init_bank_01
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank01.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank01.hex"}, samples);
`endif
            end
            2: begin: init_bank_02
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank02.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank02.hex"}, samples);
`endif
            end
            3: begin: init_bank_03
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank03.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank03.hex"}, samples);
`endif
            end
            4: begin: init_bank_04
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank04.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank04.hex"}, samples);
`endif
            end
            5: begin: init_bank_05
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank05.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank05.hex"}, samples);
`endif
            end
            6: begin: init_bank_06
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank06.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank06.hex"}, samples);
`endif
            end
            7: begin: init_bank_07
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank07.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank07.hex"}, samples);
`endif
            end
            8: begin: init_bank_08
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank08.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank08.hex"}, samples);
`endif
            end
            9: begin: init_bank_09
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank09.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank09.hex"}, samples);
`endif
            end
            10: begin: init_bank_10
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank10.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank10.hex"}, samples);
`endif
            end
            11: begin: init_bank_11
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank11.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank11.hex"}, samples);
`endif
            end
            12: begin: init_bank_12
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank12.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank12.hex"}, samples);
`endif
            end
            13: begin: init_bank_13
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank13.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank13.hex"}, samples);
`endif
            end
            14: begin: init_bank_14
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank14.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank14.hex"}, samples);
`endif
            end
            15: begin: init_bank_15
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank15.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank15.hex"}, samples);
`endif
            end
            16: begin: init_bank_16
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank16.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank16.hex"}, samples);
`endif
            end
            17: begin: init_bank_17
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank17.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank17.hex"}, samples);
`endif
            end
            18: begin: init_bank_18
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank18.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank18.hex"}, samples);
`endif
            end
            19: begin: init_bank_19
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank19.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank19.hex"}, samples);
`endif
            end
            20: begin: init_bank_20
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank20.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank20.hex"}, samples);
`endif
            end
            21: begin: init_bank_21
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank21.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank21.hex"}, samples);
`endif
            end
            22: begin: init_bank_22
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank22.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank22.hex"}, samples);
`endif
            end
            23: begin: init_bank_23
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank23.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank23.hex"}, samples);
`endif
            end
            24: begin: init_bank_24
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank24.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank24.hex"}, samples);
`endif
            end
            25: begin: init_bank_25
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank25.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank25.hex"}, samples);
`endif
            end
            26: begin: init_bank_26
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank26.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank26.hex"}, samples);
`endif
            end
            27: begin: init_bank_27
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank27.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank27.hex"}, samples);
`endif
            end
            28: begin: init_bank_28
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank28.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank28.hex"}, samples);
`endif
            end
            29: begin: init_bank_29
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank29.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank29.hex"}, samples);
`endif
            end
            30: begin: init_bank_30
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank30.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank30.hex"}, samples);
`endif
            end
            31: begin: init_bank_31
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank31.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank31.hex"}, samples);
`endif
            end
            32: begin: init_bank_32
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank32.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank32.hex"}, samples);
`endif
            end
            33: begin: init_bank_33
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank33.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank33.hex"}, samples);
`endif
            end
            34: begin: init_bank_34
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank34.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank34.hex"}, samples);
`endif
            end
            35: begin: init_bank_35
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank35.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank35.hex"}, samples);
`endif
            end
            36: begin: init_bank_36
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank36.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank36.hex"}, samples);
`endif
            end
            37: begin: init_bank_37
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank37.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank37.hex"}, samples);
`endif
            end
            38: begin: init_bank_38
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank38.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank38.hex"}, samples);
`endif
            end
            39: begin: init_bank_39
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank39.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank39.hex"}, samples);
`endif
            end
            40: begin: init_bank_40
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank40.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank40.hex"}, samples);
`endif
            end
            41: begin: init_bank_41
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank41.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank41.hex"}, samples);
`endif
            end
            42: begin: init_bank_42
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank42.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank42.hex"}, samples);
`endif
            end
            43: begin: init_bank_43
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank43.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank43.hex"}, samples);
`endif
            end
            44: begin: init_bank_44
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank44.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank44.hex"}, samples);
`endif
            end
            45: begin: init_bank_45
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank45.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank45.hex"}, samples);
`endif
            end
            46: begin: init_bank_46
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank46.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank46.hex"}, samples);
`endif
            end
            47: begin: init_bank_47
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank47.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank47.hex"}, samples);
`endif
            end
            48: begin: init_bank_48
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank48.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank48.hex"}, samples);
`endif
            end
            49: begin: init_bank_49
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank49.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank49.hex"}, samples);
`endif
            end
            50: begin: init_bank_50
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank50.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank50.hex"}, samples);
`endif
            end
            51: begin: init_bank_51
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank51.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank51.hex"}, samples);
`endif
            end
            52: begin: init_bank_52
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank52.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank52.hex"}, samples);
`endif
            end
            53: begin: init_bank_53
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank53.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank53.hex"}, samples);
`endif
            end
            54: begin: init_bank_54
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank54.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank54.hex"}, samples);
`endif
            end
            55: begin: init_bank_55
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank55.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank55.hex"}, samples);
`endif
            end
            56: begin: init_bank_56
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank56.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank56.hex"}, samples);
`endif
            end
            57: begin: init_bank_57
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank57.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank57.hex"}, samples);
`endif
            end
            58: begin: init_bank_58
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank58.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank58.hex"}, samples);
`endif
            end
            59: begin: init_bank_59
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank59.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank59.hex"}, samples);
`endif
            end
            60: begin: init_bank_60
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank60.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank60.hex"}, samples);
`endif
            end
            61: begin: init_bank_61
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank61.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank61.hex"}, samples);
`endif
            end
            62: begin: init_bank_62
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank62.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank62.hex"}, samples);
`endif
            end
            63: begin: init_bank_63
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank63.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank63.hex"}, samples);
`endif
            end
            64: begin: init_bank_64
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank64.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank64.hex"}, samples);
`endif
            end
            65: begin: init_bank_65
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank65.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank65.hex"}, samples);
`endif
            end
            66: begin: init_bank_66
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank66.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank66.hex"}, samples);
`endif
            end
            67: begin: init_bank_67
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank67.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank67.hex"}, samples);
`endif
            end
            68: begin: init_bank_68
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank68.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank68.hex"}, samples);
`endif
            end
            69: begin: init_bank_69
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank69.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank69.hex"}, samples);
`endif
            end
            70: begin: init_bank_70
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank70.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank70.hex"}, samples);
`endif
            end
            71: begin: init_bank_71
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank71.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank71.hex"}, samples);
`endif
            end
            72: begin: init_bank_72
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank72.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank72.hex"}, samples);
`endif
            end
            73: begin: init_bank_73
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank73.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank73.hex"}, samples);
`endif
            end
            74: begin: init_bank_74
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank74.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank74.hex"}, samples);
`endif
            end
            75: begin: init_bank_75
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank75.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank75.hex"}, samples);
`endif
            end
            76: begin: init_bank_76
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank76.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank76.hex"}, samples);
`endif
            end
            77: begin: init_bank_77
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank77.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank77.hex"}, samples);
`endif
            end
            78: begin: init_bank_78
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank78.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank78.hex"}, samples);
`endif
            end
            79: begin: init_bank_79
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank79.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank79.hex"}, samples);
`endif
            end
            80: begin: init_bank_80
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank80.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank80.hex"}, samples);
`endif
            end
            81: begin: init_bank_81
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank81.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank81.hex"}, samples);
`endif
            end
            82: begin: init_bank_82
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank82.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank82.hex"}, samples);
`endif
            end
            83: begin: init_bank_83
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank83.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank83.hex"}, samples);
`endif
            end
            84: begin: init_bank_84
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank84.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank84.hex"}, samples);
`endif
            end
            85: begin: init_bank_85
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank85.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank85.hex"}, samples);
`endif
            end
            86: begin: init_bank_86
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank86.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank86.hex"}, samples);
`endif
            end
            87: begin: init_bank_87
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank87.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank87.hex"}, samples);
`endif
            end
            88: begin: init_bank_88
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank88.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank88.hex"}, samples);
`endif
            end
            89: begin: init_bank_89
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank89.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank89.hex"}, samples);
`endif
            end
            90: begin: init_bank_90
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank90.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank90.hex"}, samples);
`endif
            end
            91: begin: init_bank_91
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank91.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank91.hex"}, samples);
`endif
            end
            92: begin: init_bank_92
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank92.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank92.hex"}, samples);
`endif
            end
            93: begin: init_bank_93
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank93.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank93.hex"}, samples);
`endif
            end
            94: begin: init_bank_94
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank94.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank94.hex"}, samples);
`endif
            end
            95: begin: init_bank_95
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank95.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank95.hex"}, samples);
`endif
            end
            96: begin: init_bank_96
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank96.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank96.hex"}, samples);
`endif
            end
            97: begin: init_bank_97
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank97.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank97.hex"}, samples);
`endif
            end
            98: begin: init_bank_98
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank98.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank98.hex"}, samples);
`endif
            end
            99: begin: init_bank_99
`ifdef SYNTHESIS
                initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex.bank99.hex", samples);
`else
                initial $readmemh({ROM_FILE,".bank99.hex"}, samples);
`endif
            end
        endcase
        always @(posedge clk) data_q <= samples[address % BANK_SIZE];
        assign bank_q[bank]=data_q;
    end endgenerate

    reg half;
    reg [1:0] repeats,warm;
    reg decoded_ready;
    reg signed [15:0] predictor,pcm;
    reg [6:0] step_index;
    wire [3:0] code=half?rom_q[3:0]:rom_q[7:4];
    reg [14:0] step_value;
    always @(*)begin
        case(step_index)
            0:step_value=15'd7;
            1:step_value=15'd8;
            2:step_value=15'd9;
            3:step_value=15'd10;
            4:step_value=15'd11;
            5:step_value=15'd12;
            6:step_value=15'd13;
            7:step_value=15'd14;
            8:step_value=15'd16;
            9:step_value=15'd17;
            10:step_value=15'd19;
            11:step_value=15'd21;
            12:step_value=15'd23;
            13:step_value=15'd25;
            14:step_value=15'd28;
            15:step_value=15'd31;
            16:step_value=15'd34;
            17:step_value=15'd37;
            18:step_value=15'd41;
            19:step_value=15'd45;
            20:step_value=15'd50;
            21:step_value=15'd55;
            22:step_value=15'd60;
            23:step_value=15'd66;
            24:step_value=15'd73;
            25:step_value=15'd80;
            26:step_value=15'd88;
            27:step_value=15'd97;
            28:step_value=15'd107;
            29:step_value=15'd118;
            30:step_value=15'd130;
            31:step_value=15'd143;
            32:step_value=15'd157;
            33:step_value=15'd173;
            34:step_value=15'd190;
            35:step_value=15'd209;
            36:step_value=15'd230;
            37:step_value=15'd253;
            38:step_value=15'd279;
            39:step_value=15'd307;
            40:step_value=15'd337;
            41:step_value=15'd371;
            42:step_value=15'd408;
            43:step_value=15'd449;
            44:step_value=15'd494;
            45:step_value=15'd544;
            46:step_value=15'd598;
            47:step_value=15'd658;
            48:step_value=15'd724;
            49:step_value=15'd796;
            50:step_value=15'd876;
            51:step_value=15'd963;
            52:step_value=15'd1060;
            53:step_value=15'd1166;
            54:step_value=15'd1282;
            55:step_value=15'd1411;
            56:step_value=15'd1552;
            57:step_value=15'd1707;
            58:step_value=15'd1878;
            59:step_value=15'd2066;
            60:step_value=15'd2272;
            61:step_value=15'd2499;
            62:step_value=15'd2749;
            63:step_value=15'd3024;
            64:step_value=15'd3327;
            65:step_value=15'd3660;
            66:step_value=15'd4026;
            67:step_value=15'd4428;
            68:step_value=15'd4871;
            69:step_value=15'd5358;
            70:step_value=15'd5894;
            71:step_value=15'd6484;
            72:step_value=15'd7132;
            73:step_value=15'd7845;
            74:step_value=15'd8630;
            75:step_value=15'd9493;
            76:step_value=15'd10442;
            77:step_value=15'd11487;
            78:step_value=15'd12635;
            79:step_value=15'd13899;
            80:step_value=15'd15289;
            81:step_value=15'd16818;
            82:step_value=15'd18500;
            83:step_value=15'd20350;
            84:step_value=15'd22385;
            85:step_value=15'd24623;
            86:step_value=15'd27086;
            87:step_value=15'd29794;
            88:step_value=15'd32767;
            default:step_value=32767;
        endcase
    end
    reg [16:0] magnitude;
    reg signed [17:0] reconstructed;
    reg signed [15:0] next_predictor;
    reg signed [8:0] next_index;
    always @(*)begin
        magnitude={2'b0,step_value}>>3;
        if(code[0])magnitude=magnitude+({2'b0,step_value}>>2);
        if(code[1])magnitude=magnitude+({2'b0,step_value}>>1);
        if(code[2])magnitude=magnitude+{2'b0,step_value};
        if(code[3])reconstructed=$signed({{2{predictor[15]}},predictor})-$signed({1'b0,magnitude});
        else reconstructed=$signed({{2{predictor[15]}},predictor})+$signed({1'b0,magnitude});
        if(reconstructed>18'sd32767)next_predictor=16'sh7fff;
        else if(reconstructed< -18'sd32768)next_predictor=16'sh8000;
        else next_predictor=reconstructed[15:0];
        case(code[2:0])
            4:next_index=$signed({2'b0,step_index})+9'sd2;
            5:next_index=$signed({2'b0,step_index})+9'sd4;
            6:next_index=$signed({2'b0,step_index})+9'sd6;
            7:next_index=$signed({2'b0,step_index})+9'sd8;
            default:next_index=$signed({2'b0,step_index})-9'sd1;
        endcase
        if(next_index<0)next_index=0;
        else if(next_index>88)next_index=88;
    end
    wire valid_request=request_valid&&request_asset_id>=1&&request_asset_id<=13;
    always @(posedge clk)bank_select_q<=address/BANK_SIZE;
    assign sample_valid=busy&&decoded_ready&&!valid_request;
    assign sample_pcm=pcm;
    assign sample_last=sample_valid&&remaining==1&&repeats==3;
    always @(posedge clk)begin
        if(rst)begin
            address<=0;remaining<=0;repeats<=0;warm<=0;busy<=0;
            half<=0;decoded_ready<=0;predictor<=0;pcm<=0;step_index<=0;
        end else if(valid_request)begin
            case(request_asset_id)
                1:begin address<=0;remaining<=20859;end
                2:begin address<=10430;remaining<=6985;end
                3:begin address<=13923;remaining<=8921;end
                4:begin address<=18384;remaining<=13348;end
                5:begin address<=25058;remaining<=13610;end
                6:begin address<=31863;remaining<=13661;end
                7:begin address<=38694;remaining<=15904;end
                8:begin address<=46646;remaining<=18456;end
                9:begin address<=55874;remaining<=30152;end
                10:begin address<=70950;remaining<=24412;end
                11:begin address<=83156;remaining<=21857;end
                12:begin address<=94085;remaining<=25272;end
                13:begin address<=106721;remaining<=24332;end
                default:begin address<=0;remaining<=0;end
            endcase
            half<=0;repeats<=0;warm<=2;busy<=1;decoded_ready<=0;
            predictor<=0;pcm<=0;step_index<=0;
        end else if(busy)begin
            if(warm!=0)warm<=warm-1'b1;
            else if(!decoded_ready)begin
                predictor<=next_predictor;pcm<=next_predictor;step_index<=next_index[6:0];decoded_ready<=1;
            end else if(sample_ready)begin
                if(repeats==3)begin
                    repeats<=0;decoded_ready<=0;
                    if(remaining==1)begin busy<=0;remaining<=0;end
                    else begin
                        remaining<=remaining-1'b1;half<=!half;
                        if(half)begin address<=address+1'b1;warm<=2;end
                    end
                end else repeats<=repeats+1'b1;
            end
        end
    end
endmodule
