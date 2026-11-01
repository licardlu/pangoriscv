ins_new E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/min3.fic
ins_set_file -input E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/pangoriscv_top_syn.adf
ins_add_core 1
ins_set_core -core 0 -enable_sq 0 -data_same 0 -data_depth 512 -trig_num 1 -clock_edge 0 -power 1 -multi_windows 0
ins_set_trig -core 0 -trig 0 -unit_num 1 -as_data 0
ins_set_net -core 0 -trig 0 -connect {15274 1503}
ins_set_net -core 0 -clock {4295}
ins_set_net -core 0 -reset {22940}
ins_core_info -core 0
ins_save
exit
