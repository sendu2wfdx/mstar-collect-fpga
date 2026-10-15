create_clock -name {clk_25mhz} -period 20.000 -waveform {0.000 10.000} [get_ports {clk_50m}]
create_clock -name {clk_125mhz} -period 4.000 -waveform {0.000 2.000} [get_ports {rgmii_rxc}]
derive_clocks
rename_clock -name {w_clk125M} [get_clocks {sysPLL_u0/ph1p_phy_pll_wrapper_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {w_clk100M} [get_clocks {sysPLL_u0/ph1p_phy_pll_wrapper_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {w_clk50M} [get_clocks {sysPLL_u0/ph1p_phy_pll_wrapper_Inst/u_PH1P_PHY_PLL.clkc[2]}]

set_max_delay -from [get_clocks {w_clk125M}] -to [get_clocks {w_clk100M}] -datapath_only 8.000
set_max_delay -from [get_clocks {w_clk100M}] -to [get_clocks {w_clk125M}] -datapath_only 8.000
set_max_delay -from [get_clocks {w_clk125M}] -to [get_clocks {w_clk50M}] -datapath_only 40.000
set_max_delay -from [get_clocks {w_clk50M}] -to [get_clocks {w_clk125M}] -datapath_only 40.000
set_max_delay -from [get_clocks {w_clk100M}] -to [get_clocks {w_clk50M}] -datapath_only 40.000
set_max_delay -from [get_clocks {w_clk50M}] -to [get_clocks {w_clk100M}] -datapath_only 40.000
set_max_delay -from [get_clocks {w_clk100M}] -to [get_clocks {MIS_DDR_u/usr_clk}] -datapath_only 15.000
set_max_delay -from [get_clocks {MIS_DDR_u/usr_clk}] -to [get_clocks {w_clk100M}] -datapath_only 10.000
set_max_delay -from [get_clocks {mstar_ethernet_bridge_u0/mstar_rgmii_u0/rgmii_interface_u0/u_PH1P_PHY_LCLK.clkout}] -to [get_clocks {mstar_ethernet_bridge_u0/mstar_rgmii_u0/rgmii_interface_u0/u_PH1P_PHY_LCLK.clkout}] 8.000
