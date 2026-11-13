ins_new D:/FPGA_Project/zi_guang_tong_chuang/tmp/ila/ila.fic
ins_set_file -input D:/FPGA_Project/zi_guang_tong_chuang/tmp/ila/netlist.adf
ins_add_core 1
ins_set_core -core 0 -data_depth 4096 -trig_num 1 -data_same 1
ins_operate -core 0 -trig 0
ins_set_trig -core 0 -trig 0 -unit_num 1 -type 1
ins_set_net -core 0 -data -clock "642"
ins_set_net -core 0 -trig 0 "15038 6550 11969 5310 17953 5390 13780 4977 13322 6745 14982 2950 15661 15288 17424 8359 8625 18450 18928 17044 6199 14661 4440 15929 17354 11135 7538 11654 7896 8530 10578 1436 13532 10196 7716 11512 1689 14373 15105 8915 12315 1546 13851 3471 13189 8799 17666 855 16951 16 611 13873 5136 13013 10991 12035 18503 896 8534 9960 1885 16284 10698 2093 1271 8423 2541"
ins_set_unit -core 0 -unit 0 -func "==" -value "0001000000001000000000000000001XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
ins_core_info -core 0 -trig 0 -unit 0
ins_save D:/FPGA_Project/zi_guang_tong_chuang/tmp/ila/ila.fic
puts "FIC_DONE"
