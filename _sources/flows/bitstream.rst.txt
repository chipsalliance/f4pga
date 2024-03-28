Bitstream translation
#####################

The routing process results in an output file specifying the used blocks
and routing paths. It contains the resources that needs to be instantiated
on the FPGA chip, however, the output format is not understood
by the FPGA chip itself.

In the last step, the description of the chip is translated into
the appropriate format, suitable for the chosen FPGA.
That final file contains instructions readable by the configuration block of
the desired chip.

Documenting the bitstream format for different FPGA chips is one of the
most important tasks in the F4PGA Project!
