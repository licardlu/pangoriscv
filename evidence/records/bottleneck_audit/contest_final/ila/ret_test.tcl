ins_new E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/ret_test.fic
ins_set_file -input E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/pangoriscv_top_syn.adf
ins_add_core 1
set r [ins_list_nets]
set f [open E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/listret.txt w]
puts $f "TYPELEN=[string length $r] ELEMS=[llength $r]"
puts $f $r
close $f
set r2 [ins_core_info -core 0]
set f2 [open E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/inforet.txt w]
puts $f2 "TYPELEN=[string length $r2] ELEMS=[llength $r2]"
puts $f2 $r2
close $f2
exit
