
# Preliminary DDR input timing constraints.
# Experimental only. Not final hardware sign-off.

# ADC channels 0 and 1
set_input_delay -clock [get_clocks adc_clk0_in] -min 2.0 [get_ports -regexp {^adc_data_pins\[[01]\]\[[0-6]\]$}]
set_input_delay -clock [get_clocks adc_clk0_in] -max 2.6 [get_ports -regexp {^adc_data_pins\[[01]\]\[[0-6]\]$}]
set_input_delay -clock [get_clocks adc_clk0_in] -clock_fall -add_delay -min 2.0 [get_ports -regexp {^adc_data_pins\[[01]\]\[[0-6]\]$}]
set_input_delay -clock [get_clocks adc_clk0_in] -clock_fall -add_delay -max 2.6 [get_ports -regexp {^adc_data_pins\[[01]\]\[[0-6]\]$}]

# ADC channels 2 and 3
set_input_delay -clock [get_clocks adc_clk1_in] -min 2.0 [get_ports -regexp {^adc_data_pins\[[23]\]\[[0-6]\]$}]
set_input_delay -clock [get_clocks adc_clk1_in] -max 2.6 [get_ports -regexp {^adc_data_pins\[[23]\]\[[0-6]\]$}]
set_input_delay -clock [get_clocks adc_clk1_in] -clock_fall -add_delay -min 2.0 [get_ports -regexp {^adc_data_pins\[[23]\]\[[0-6]\]$}]
set_input_delay -clock [get_clocks adc_clk1_in] -clock_fall -add_delay -max 2.6 [get_ports -regexp {^adc_data_pins\[[23]\]\[[0-6]\]$}]

