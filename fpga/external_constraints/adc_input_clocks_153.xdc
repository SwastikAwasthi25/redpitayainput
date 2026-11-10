# Trial project ADC primary clock constraints
create_clock -name adc_clk0_in -period 8.000 -waveform {0.000 4.000} [get_ports adc_clk0_p]
create_clock -name adc_clk1_in -period 8.000 -waveform {0.000 4.000} [get_ports adc_clk1_p]
