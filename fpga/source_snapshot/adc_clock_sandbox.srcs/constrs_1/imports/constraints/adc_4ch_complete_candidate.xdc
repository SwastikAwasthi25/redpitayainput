# Candidate XDC - NOT YET APPLIED
# Source: stream_app_4ch/sdc/red_pitaya_4ADC.xdc
# Board revision must be verified before programming.

set_property PACKAGE_PIN Y17 [get_ports {adc_data_pins[0][0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][0]}]

set_property PACKAGE_PIN Y16 [get_ports {adc_data_pins[0][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][1]}]

set_property PACKAGE_PIN W14 [get_ports {adc_data_pins[0][2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][2]}]

set_property PACKAGE_PIN Y14 [get_ports {adc_data_pins[0][3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][3]}]

set_property PACKAGE_PIN V12 [get_ports {adc_data_pins[0][4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][4]}]

set_property PACKAGE_PIN W13 [get_ports {adc_data_pins[0][5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][5]}]

set_property PACKAGE_PIN V13 [get_ports {adc_data_pins[0][6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[0][6]}]

set_property PACKAGE_PIN W15 [get_ports {adc_data_pins[1][0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][0]}]

set_property PACKAGE_PIN W16 [get_ports {adc_data_pins[1][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][1]}]

set_property PACKAGE_PIN V15 [get_ports {adc_data_pins[1][2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][2]}]

set_property PACKAGE_PIN V16 [get_ports {adc_data_pins[1][3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][3]}]

set_property PACKAGE_PIN Y19 [get_ports {adc_data_pins[1][4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][4]}]

set_property PACKAGE_PIN W18 [get_ports {adc_data_pins[1][5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][5]}]

set_property PACKAGE_PIN Y18 [get_ports {adc_data_pins[1][6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[1][6]}]

set_property PACKAGE_PIN W20 [get_ports {adc_data_pins[2][0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][0]}]

set_property PACKAGE_PIN W19 [get_ports {adc_data_pins[2][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][1]}]

set_property PACKAGE_PIN V17 [get_ports {adc_data_pins[2][2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][2]}]

set_property PACKAGE_PIN V18 [get_ports {adc_data_pins[2][3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][3]}]

set_property PACKAGE_PIN U17 [get_ports {adc_data_pins[2][4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][4]}]

set_property PACKAGE_PIN T16 [get_ports {adc_data_pins[2][5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][5]}]

set_property PACKAGE_PIN T17 [get_ports {adc_data_pins[2][6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[2][6]}]

set_property PACKAGE_PIN R19 [get_ports {adc_data_pins[3][0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][0]}]

set_property PACKAGE_PIN R17 [get_ports {adc_data_pins[3][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][1]}]

set_property PACKAGE_PIN T15 [get_ports {adc_data_pins[3][2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][2]}]

set_property PACKAGE_PIN R16 [get_ports {adc_data_pins[3][3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][3]}]

set_property PACKAGE_PIN T20 [get_ports {adc_data_pins[3][4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][4]}]

set_property PACKAGE_PIN U20 [get_ports {adc_data_pins[3][5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][5]}]

set_property PACKAGE_PIN V20 [get_ports {adc_data_pins[3][6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data_pins[3][6]}]

set_property PACKAGE_PIN U18 [get_ports {adc_clk0_p}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {adc_clk0_p}]

set_property PACKAGE_PIN U19 [get_ports {adc_clk0_n}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {adc_clk0_n}]

set_property PACKAGE_PIN N20 [get_ports {adc_clk1_p}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {adc_clk1_p}]

set_property PACKAGE_PIN P20 [get_ports {adc_clk1_n}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {adc_clk1_n}]

set_property PACKAGE_PIN P15 [get_ports {spi_csa_o}]
set_property IOSTANDARD LVCMOS18 [get_ports {spi_csa_o}]
set_property SLEW FAST [get_ports {spi_csa_o}]
set_property DRIVE 8 [get_ports {spi_csa_o}]

set_property PACKAGE_PIN P16 [get_ports {spi_csb_o}]
set_property IOSTANDARD LVCMOS18 [get_ports {spi_csb_o}]
set_property SLEW FAST [get_ports {spi_csb_o}]
set_property DRIVE 8 [get_ports {spi_csb_o}]

set_property PACKAGE_PIN P18 [get_ports {spi_clk_o}]
set_property IOSTANDARD LVCMOS18 [get_ports {spi_clk_o}]
set_property SLEW FAST [get_ports {spi_clk_o}]
set_property DRIVE 8 [get_ports {spi_clk_o}]

set_property PACKAGE_PIN N17 [get_ports {spi_mosi_o}]
set_property IOSTANDARD LVCMOS18 [get_ports {spi_mosi_o}]
set_property SLEW FAST [get_ports {spi_mosi_o}]
set_property DRIVE 8 [get_ports {spi_mosi_o}]

