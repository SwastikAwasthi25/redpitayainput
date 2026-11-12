# Fresh build from *cloned* exported sources only; no original D:/ project is opened.
# Invocation: vivado -mode batch -source vivado_clean_rebuild.tcl -tclargs <clone_directory> <build_directory>

set vivadoVersion [version -short]
puts "VIVADO_VERSION: $vivadoVersion"
if {![string match "2025.2*" $vivadoVersion]} {
    error "STOP: Expected Vivado 2025.2; found $vivadoVersion"
}

proc stop {message} {error "STOP: $message"}
if {[llength $argv] != 2} {stop "Expected exactly two arguments: clone_directory build_directory"}
set cloneDir [file normalize [lindex $argv 0]]
set buildDir [file normalize [lindex $argv 1]]
set snapshot [file join $cloneDir fpga source_snapshot adc_clock_sandbox.srcs]
set rtlDir [file join $snapshot sources_1 imports rtl]
set ipDir [file join $snapshot sources_1 ip]
set bdFile [file join $snapshot sources_1 bd adc_ps_startup adc_ps_startup.bd]
set baseXdc [file join $snapshot constrs_1 imports constraints adc_4ch_complete_candidate.xdc]
set clockXdc [file join $cloneDir fpga external_constraints adc_input_clocks_153.xdc]
set adcXdc [file join $cloneDir fpga external_constraints adc_ddr_trial_184.xdc]
set cdcXdc [file join $cloneDir fpga external_constraints adc_cdc_verified_199.xdc]

if {![file isdirectory $rtlDir]} {stop "Missing RTL folder inside clone"}
foreach path [list $bdFile $baseXdc $clockXdc $adcXdc $cdcXdc] {
    if {![file exists $path]} {stop "Missing cloned build input: $path"}
}

set rtlFiles {}
foreach item [lsort [glob -nocomplain -directory $rtlDir *]] {
    if {[file isfile $item] && [file extension $item] in {.v .sv}} {
        lappend rtlFiles $item
    }
}
if {[llength $rtlFiles] != 12} {
    stop "Expected exactly 12 real RTL sources in clone; found [llength $rtlFiles]"
}

# Single-ILA variant is an overlay, NOT a modification of the SHA256-verified
# original adc_ila_top.sv. The other 11 original RTL files are kept unchanged.
set originalIlaTop [file join $rtlDir adc_ila_top.sv]
set variantIlaTop [file join $cloneDir variants single_ila_4ch adc_ila_top.sv]
if {![file exists $variantIlaTop]} {stop "Single-ILA variant RTL missing: $variantIlaTop"}
set oldIndex [lsearch -exact $rtlFiles $originalIlaTop]
if {$oldIndex < 0} {stop "Cannot locate the original adc_ila_top.sv in the source list"}
set rtlFiles [lreplace $rtlFiles $oldIndex $oldIndex]
lappend rtlFiles $variantIlaTop
if {[llength $rtlFiles] != 12} {stop "Variant must compile exactly 12 RTL sources"}
puts "SINGLE_ILA_OVERLAY_SOURCE: $variantIlaTop"

set ipFiles {}
foreach ipName {adc_clk_wiz_01 adc_clk_wiz_23 adc_ila_12 adc_ila_34} {
    set f [file join $ipDir $ipName ${ipName}.xci]
    if {![file exists $f]} {stop "Missing original XCI: $f"}
    lappend ipFiles $f
}

# The copied XPR is deliberately not opened: it contains the original D:/ path.
# A new project is created using ONLY the clone's actual RTL, XCI, BD, and XDC.
set projectPath [file join $buildDir fresh_project]
puts "CLONE_INPUT_ROOT: $cloneDir"
puts "INDEPENDENT_PROJECT_PATH: $projectPath"
puts "ACTUAL_RTL_FILES: [llength $rtlFiles]"

create_project adc_fresh_clone $projectPath -part xc7z020clg400-1
set_property target_language Verilog [current_project]
add_files -fileset sources_1 -norecurse $rtlFiles
add_files -fileset sources_1 -norecurse $ipFiles
add_files -fileset sources_1 -norecurse $bdFile
set_property top adc_system_top [get_filesets sources_1]

foreach xdc [list $baseXdc $clockXdc $adcXdc $cdcXdc] {
    add_files -fileset constrs_1 -norecurse $xdc
}
set_property PROCESSING_ORDER EARLY [get_files $clockXdc]
set_property PROCESSING_ORDER LATE [get_files $adcXdc]
set_property PROCESSING_ORDER LATE [get_files $cdcXdc]
set_property USED_IN_SYNTHESIS false [get_files $cdcXdc]
set_property USED_IN_IMPLEMENTATION true [get_files $cdcXdc]

# Recreate standard IP outputs from the original *.xci and *.bd definitions.
# Fail on IP errors rather than borrowing old synthesized run DCP files.
update_ip_catalog
foreach f [concat $ipFiles [list $bdFile]] {
    generate_target all [get_files $f]
}
# Generate the original block design's HDL wrapper.
# adc_system_top instantiates adc_ps_startup_wrapper.
set bdObjects [get_files -quiet $bdFile]

if {[llength $bdObjects] != 1} {
    stop "Expected exactly one ADC PS startup block design"
}

set wrapperFiles [make_wrapper -files $bdObjects -top]

if {[llength $wrapperFiles] != 1} {
    stop "Expected exactly one generated BD wrapper"
}

foreach wf $wrapperFiles {
    if {![file exists $wf]} {
        stop "Generated BD wrapper file missing: $wf"
    }
}

add_files -fileset sources_1 -norecurse $wrapperFiles

set_property top adc_system_top [get_filesets sources_1]

puts "FRESH_BD_WRAPPER_ADDED: $wrapperFiles"
update_compile_order -fileset sources_1

set synth [get_runs synth_1]
launch_runs $synth -jobs 4
wait_on_run $synth
set ss [get_property STATUS $synth]
puts "FRESH_SYNTH_STATUS: $ss"
if {![string match "*Complete*" $ss]} {stop "Fresh synthesis did not complete"}

set impl [get_runs impl_1]
launch_runs $impl -to_step write_bitstream -jobs 4
wait_on_run $impl
set is [get_property STATUS $impl]
puts "FRESH_IMPL_STATUS: $is"
if {![string match "write_bitstream Complete*" $is]} {stop "Fresh bitstream implementation did not complete"}

open_run impl_1
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup] != 1 || [llength $hold] != 1} {stop "Missing global setup or hold timing path"}
set wns [get_property SLACK $setup]
set whs [get_property SLACK $hold]
puts "FRESH_GLOBAL_SETUP_SLACK_NS: $wns"
puts "FRESH_GLOBAL_HOLD_SLACK_NS: $whs"
if {$wns <= 0 || $whs <= 0} {stop "Fresh build has nonpositive setup/hold margin"}

report_timing_summary -delay_type min_max -report_unconstrained -no_detailed_paths -file [file join $buildDir timing_summary.rpt]
report_bus_skew -sort_by_slack -no_detailed_paths -file [file join $buildDir bus_skew.rpt]
report_drc -file [file join $buildDir drc.rpt]
report_cdc -details -file [file join $buildDir cdc_review.rpt]

set builtBit [file join $projectPath adc_fresh_clone.runs impl_1 adc_system_top.bit]
if {![file exists $builtBit] || [file size $builtBit] <= 0} {
    stop "Expected new bitstream missing: $builtBit"
}
set outBit [file join $buildDir adc_system_top_single_ila_trial.bit]
file copy -force $builtBit $outBit
set outLtx [file join $buildDir adc_system_top_single_ila_trial.ltx]
write_debug_probes $outLtx
if {![file exists $outLtx] || [file size $outLtx] <= 0} {
    stop "Matching new debug probe file missing"
}

set commit [string trim [exec git -C $cloneDir rev-parse HEAD]]
set pass [open [file join $buildDir SINGLE_ILA_TRIAL_BUILD_PASS.txt] w]
puts $pass "variant=single_ila_4ch_twos_complement_async_fifo"
puts $pass "hardware_validation=NOT_PERFORMED"
puts $pass "cdc_review=REQUIRED"
puts $pass "adc_pair_alignment=NOT_ESTABLISHED"
puts $pass "source_commit=$commit"
puts $pass "setup_slack_ns=$wns"
puts $pass "hold_slack_ns=$whs"
puts $pass "new_bitstream=$outBit"
puts $pass "new_probes=$outLtx"
puts $pass "build_scope=separate clean Vivado project from exported sources; same PC; no hardware retest"
close $pass
puts "SINGLE_ILA_TRIAL_BUILD_PASS: $commit"
