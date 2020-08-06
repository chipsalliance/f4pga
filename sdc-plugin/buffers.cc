#include "buffers.h"

const std::vector<std::string> Pll::inputs = {"CLKIN1", "CLKIN2"};
const std::vector<std::string> Pll::outputs = {"CLKOUT0", "CLKOUT1", "CLKOUT2", "CLKOUT3", "CLKOUT4", "CLKOUT5"};
const float Pll::delay = 1;
const std::string Pll::name = "PLLE2_ADV";
