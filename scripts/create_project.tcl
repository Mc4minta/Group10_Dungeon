# สร้าง Vivado project จาก source ใน repo
#   cd Group10_Dungeon
#   vivado -mode batch -source scripts/create_project.tcl              (สร้าง project อย่างเดียว)
#   vivado -mode batch -source scripts/create_project.tcl -tclargs build   (สร้าง + bitstream)
# หรือใน Vivado GUI: Tools > Run Tcl Script... เลือกไฟล์นี้
# project อยู่ที่ vivado/ (ไม่ commit) ลบทิ้งแล้วสร้างใหม่ได้ทุกเมื่อ

set root [file normalize [file dirname [info script]]/..]
set proj_dir $root/vivado

create_project -force Group10_Dungeon $proj_dir -part xc7a100tcsg324-1

add_files -norecurse [glob $root/rtl/*.v]
add_files -norecurse $root/rtl/params.vh
set_property file_type {Verilog Header} [get_files params.vh]
set_property include_dirs [list $root/rtl] [get_filesets sources_1]
set_property include_dirs [list $root/rtl] [get_filesets sim_1]
add_files -norecurse [glob $root/mem/*.mem]
set_property file_type {Memory Initialization Files} [get_files *.mem]
add_files -fileset constrs_1 -norecurse $root/constraints/nexys_a7.xdc
add_files -fileset sim_1 -norecurse [glob $root/sim/*.v]

set_property top top [current_fileset]
set_property top tb_top [get_filesets sim_1]
update_compile_order -fileset sources_1

if {[llength $argv] > 0 && [lindex $argv 0] eq "build"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    puts "bitstream: $proj_dir/Group10_Dungeon.runs/impl_1/top.bit"
}
