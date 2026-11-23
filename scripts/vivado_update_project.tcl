# Bring an OPEN Vivado project up to date with the files in the repository (adds every rtl/*.v and mem/*.mem that the project does not know yet).
# Use it when synthesis says "module 'xxx' not found" (the project was created before that file existed).
#   In the Vivado Tcl Console:   source <path-to-your-clone>/scripts/vivado_update_project.tcl
# Then click Generate Bitstream. (Alternative that rebuilds the whole project: scripts/create_project.tcl with the project closed.)
set root [file normalize [file dirname [info script]]/..]
set added 0
foreach f [lsort [glob $root/rtl/*.v]] {
    if {[llength [get_files -quiet $f]] == 0} {
        add_files -norecurse $f
        puts "ADDED  $f"
        incr added
    }
}
foreach f [lsort [glob $root/mem/*.mem]] {
    if {[llength [get_files -quiet $f]] == 0} {
        add_files -norecurse $f
        puts "ADDED  $f"
        incr added
    }
}
set_property file_type {Memory Initialization Files} [get_files *.mem]
set_property file_type {Verilog Header} [get_files -quiet params.vh]
set_property include_dirs [list $root/rtl] [get_filesets sources_1]
update_compile_order -fileset sources_1
catch {reset_run synth_1}
puts "---------------------------------------------------------------"
puts "Project updated: $added file(s) added. Required modules present:"
foreach m {face_lock player_frame hud audio objects boss puzzles objline renderer} {
    puts [format "  %-13s %s" $m [expr {[llength [get_files -quiet $root/rtl/$m.v]] ? "OK" : "MISSING"}]]
}
puts "Now click Generate Bitstream."
