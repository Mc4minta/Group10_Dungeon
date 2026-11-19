# Vivado batch synthesis report (BRAM + timing estimate). Does NOT build a bitstream.
#   E:\Xilinx\Vivado\2024.2\bin\vivado.bat -mode batch -source scripts/vivado_synth.tcl
# Creates a throw-away project in vivado/ (ignored by git), runs synth_1, then writes:
#   vivado/reports/utilization.txt   (RAMB36 / RAMB18 / LUT / FF)
#   vivado/reports/timing.txt        (WNS after synthesis; routed timing needs impl_1)
set root [file normalize [file dirname [info script]]/..]
source $root/scripts/create_project.tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "SYNTH FAILED: [get_property STATUS [get_runs synth_1]]"
    exit 1
}
open_run synth_1
file mkdir $root/vivado/reports
report_utilization -file $root/vivado/reports/utilization.txt
report_utilization -hierarchical -file $root/vivado/reports/utilization_hier.txt
report_timing_summary -delay_type max -max_paths 5 -file $root/vivado/reports/timing.txt
puts "REPORTS: $root/vivado/reports"
exit 0
