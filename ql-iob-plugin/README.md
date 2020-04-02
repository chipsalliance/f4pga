# QuickLogic IO buffer plugin

This plugin allows to annotate IO buffer cells with information from IO placement constraints. This is required to determine at the netlist level what types of IO buffers have to be used where.

The plugin reads IO constraints from a PCF file and a board pinmap from a pinmap CSV file. The pinmap file should contain the followin columns: `name`, `x`, `y` and `type` (optional). Basing on this information each IO cell has the following parameters set:

- IO_PAD - Name of the IO pad,
- IO_LOC - Location of the IO pad (eg. "X10Y20"),
- IO_TYPE - Type of the IO buffer (to be used inside techmap).

See the plugin's help for more details.
