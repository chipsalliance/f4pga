Getting started
###############

To begin using F4PGA, you might want to take a look at the tutorials below, which make for a good starting point.
They will guide you through the process of using the toolchain, explaining how to generate and load a bitstream into
your FPGA.

* `Examples ➚ <https://f4pga-examples.readthedocs.io>`__ (for users)

* `Architecture Definitions ➚ <https://f4pga.readthedocs.io/projects/arch-defs/en/latest/getting-started.html>`__ (for developers)

  * `F4PGA Architectures Visualizer ➚ <https://chipsalliance.github.io/f4pga-database-visualizer/>`__

  * `Project X-Ray ➚ <https://f4pga.readthedocs.io/projects/prjxray/en/latest/>`__

    * `X-Ray Quickstart ➚ <https://f4pga.readthedocs.io/projects/prjxray/en/latest/db_dev_process/readme.html#quickstart-guide>`__

  * `Project Trellis ➚ <https://prjtrellis.readthedocs.io/en/latest/>`__

  * :gh:`Project Icestorm ➚ <f4pga/icestorm>`


.. _GettingStarted:LoadingBitstreams:

Loading bitstreams
==================

For every board, the loading process may vary and different tools may be required.
Typically, each tool supports a specific target family or the lines of products of a vendor.
Some of the most known are listed in :ref:`hdl/constraints: Programming and debugging <constraints:ProgDebug>`.
The tools used in the F4PGA Toolchain are e.g. ``OpenOCD``, ``tinyfpgab`` or ``tinyprog``.
Moreover, :gh:`OpenFPGALoader <trabucayre/openFPGALoader>` is a universal utility for programming FPGA devices, which is
becoming an alternative to the fragmentation in bitstream loading tools.
OpenFPGALoader supports many different boards with FPGAs based on the architectures including xc7, ECP5, iCE40 and many
more.
It can utilize a variety of the programming adapters based on JTAG, DAP interface, ORBTrace, DFU and FTDI chips.

Installing OpenFPGALoader
-------------------------

OpenFPGALoader is available in several packaging solutions.
It can be installed with distribution specific package managers on Arch Linux and Fedora.
There are also prebuilt packages available in `conda <https://anaconda.org/litex-hub/openfpgaloader>`__
or packages in tool :gh:`repository <trabucayre/openFPGALoader/releases>`.
OpenFPGALoader can also be built from sources.
For installation guidelines using both prebuilt packages and building from source, please refer to instructions in
:gh:`readme <trabucayre/openFPGALoader/blob/master/INSTALL.md>`.

Usage
-----

For programming the FPGA, use one of these commands:

.. sourcecode:: bash

    openFPGALoader -b <board> <bitstream>           # (e.g. arty)
    openFPGALoader -c <cable> <bitstream>           # (e.g. digilent)
    openFPGALoader -d <device> <bitstream>          # (e.g. /dev/ttyUSB0)

You can also list the supported boards, cables and FPGAs:

.. sourcecode:: bash

    openFPGALoader --list-boards
    openFPGALoader --list-cables
    openFPGALoader --list-fpga

If you encounter any issues, please refer to :doc:`openfpgaloader:index`.
