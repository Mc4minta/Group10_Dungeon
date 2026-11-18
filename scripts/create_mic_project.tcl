# สร้าง Vivado project ตัวทดสอบไมค์ (top = mic_test_top) -> vivado_mic/
#   vivado -mode batch -source scripts/create_mic_project.tcl              (สร้าง project อย่างเดียว)
#   vivado -mode batch -source scripts/create_mic_project.tcl -tclargs build   (สร้าง + bitstream)
# ใช้ part เดียวกับเกม (xc7a100tcsg324-1); บิตสตรีมอยู่ที่ vivado_mic/mic_test.runs/impl_1/mic_test_top.bit

set root [file normalize [file dirname [info script]]/..]
set proj_dir $root/vivado_mic

create_project -force mic_test $proj_dir -part xc7a100tcsg324-1

add_files -norecurse $root/rtl/mic_test_top.v $root/rtl/pdm_mic.v $root/rtl/seg7.v $root/rtl/debounce.v $root/rtl/bin2bcd.v
add_files -norecurse $root/rtl/params.vh
set_property file_type {Verilog Header} [get_files params.vh]
set_property include_dirs [list $root/rtl] [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse $root/constraints/mic_test.xdc

set_property top mic_test_top [current_fileset]
update_compile_order -fileset sources_1

if {[llength $argv] > 0 && [lindex $argv 0] eq "build"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    puts "bitstream: $proj_dir/mic_test.runs/impl_1/mic_test_top.bit"
}
