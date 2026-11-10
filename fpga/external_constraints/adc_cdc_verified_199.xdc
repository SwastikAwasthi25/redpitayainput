
# Experimental ADC CDC constraints.
# Verified two-stage synchronizers in routed design.
# Only first-stage crossings are excluded.

set_false_path -from [get_pins -quiet {u_adc_bridge/u_adc_ila/u_frontend/u_adc_clocks/u_idelay_reset/calibration_ready_reg_reg/C}] -to [get_pins -quiet {u_adc_bridge/u_adc_ila/status12_meta_reg[3]/D}]

set_false_path -from [get_pins -quiet {u_adc_bridge/u_adc_ila/u_frontend/u_adc_clocks/u_idelay_reset/calibration_ready_reg_reg/C}] -to [get_pins -quiet {u_adc_bridge/u_adc_ila/status34_meta_reg[3]/D}]

