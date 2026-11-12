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


# PRELIMINARY CHECK ONLY: this ends after SYNTHESIS.
# A successful synth does NOT mean timing/CDC/routing/hardware passed.
open_run synth_1
report_utilization -file [file join $buildDir synth_utilization.rpt]
report_cdc -details -file [file join $buildDir synth_cdc_preliminary.rpt]

# Existence of the expected single ILA instance is checked in the RTL
# overlay; inspect the synthesized hierarchy/utilization for resource count.
set f [open [file join $buildDir SYNTHESIS_ONLY_PASS.txt] w]
puts $f "source_commit=[string trim [exec git -C $cloneDir rev-parse HEAD]]"
puts $f "status=SYNTHESIS_ONLY_NOT_CDC_OR_HARDWARE_SIGNOFF"
puts $f "check=synth_utilization.rpt and synth_cdc_preliminary.rpt"
close $f
puts "SINGLE_ILA_SYNTH_ONLY_PASS"
