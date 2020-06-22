================================
SymbiFlow Examples on Arty Board
================================

.. _SymbiFlow Examples: https://github.com/SymbiFlow/symbiflow-examples
.. _Digilent Arty A7-35T Board: https://store.digilentinc.com/arty-a7-artix-7-fpga-development-board-for-makers-and-hobbyists/

The purpose of this tutorial is to familiarize the user with the examples
showing how to use the SymbiFlow Toolchain in practice. The tutorial is designed
for a `Digilent Arty A7-35T Board`_ and uses the examples provided in the
`SymbiFlow Examples`_ repository.

.. contents:: Tutorial Steps
  :local:

1. Required Hardware
--------------------

To complete this tutorial, you need:

  - `Digilent Arty A7-35T Board`_
  - USB A to Micro-B cable
  - Ethernet cable (for the LiteX Linux Example)

.. image:: ../images/arty.png
   :width: 33%

.. image:: ../images/usb-a-to-micro-b-cable.png
   :width: 33%

.. image:: ../images/ethernet-cable.png
   :width: 33%


2. Download SymbiFlow Examples
------------------------------

All the examples used in this tutorial are located in the `SymbiFlow Examples`_
repository. Download them using:

.. code-block:: bash

   git clone https://github.com/SymbiFlow/symbiflow-examples

3. Install SymbiFlow Toolchain
------------------------------

Before generating the bitstream, you need to install the SymbiFlow Toolchain,
which contains all the necessary tools to synthesize and implement the example
designs. If you haven't installed the toolchain already, the following steps
will guide you through the entire process. More information about the
SymbiFlow Toolchain can be found in the dedicated
:doc:`documentation chapter <../toolchain-desc>`.

.. note::

   All the commands provided below should be used in the same terminal session.

#. Install the required system packages:

   .. tabs::

       .. group-tab:: Ubuntu

          .. code-block::

               sudo apt install git wget picocom


       .. group-tab:: Arch Linux

           .. code-block::

               pacman -Sy git wget picocom

#. Download the conda installer

   .. code-block:: bash

      wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O conda_installer.sh

#. Download and install the toolchain files:

   .. code-block:: bash

      INSTALL_DIR="/opt/symbiflow/xc7"
      bash conda_installer.sh -b -p $INSTALL_DIR/conda && rm conda_installer.sh
      source "$INSTALL_DIR/conda/etc/profile.d/conda.sh"
      conda env create -f symbiflow-examples/examples/xc7/environment.yml
      conda activate xc7
      wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/4/20200416-002215/symbiflow-arch-defs-install-a321d9d9.tar.xz | tar -xJ -C $INSTALL_DIR

   .. note::

      The toolchain installation directory can be modified by changing
      the ``INSTALL_DIR`` environment variable.

#. Install the required packages from the ``symbiflow`` conda channel:

   .. code-block:: bash

      conda install -y -c symbiflow openocd

#. Close the conda environment:

   .. code-block:: bash

      conda deactivate

4. Activate the conda environment
---------------------------------

#. Add SymbiFlow Toolchain to the system ``$PATH`` variable:

   .. code-block:: bash

      export INSTALL_DIR="/opt/symbiflow/xc7"
      export PATH="$INSTALL_DIR/install/bin:$PATH"

#. Activate the conda environment:

   .. code-block:: bash

      source "$INSTALL_DIR/conda/etc/profile.d/conda.sh"
      conda activate

5. Connect the Arty Board
-------------------------

#. Connect the board to your computer using the USB cable:

#. Connect the board to your computer using the Ethernet cable
   (only if you want to test the LiteX Linux Example)

.. image:: ../images/arty-usb-ethernet.png
   :width: 49%
   :align: center

6. Counter Example
------------------

The counter example is a simple design that implements the binary counter,
which displays its output on the board's LEDs. To generate and load the bitstream
with the design, follow the steps below:

#. Generate the counter example bitstream using the SymbiFlow Toolchain:

   .. code-block:: bash

      cd symbiflow-examples/examples/xc7/counter_test
      TARGET="arty" make

#. Load the bitstream to the board with OpenOCD:

   .. code-block:: bash

      openocd -f ${INSTALL_DIR}/conda/share/openocd/scripts/board/digilent_arty.cfg -c "init; pld load 0 build/top.bit; exit"

#. Check if the design is working correctly.

   - You should observe the following line in the OpenOCD output:

   .. code-block:: bash

      Info : JTAG tap: xc7.tap tap/device found: 0x0362d093 (mfg: 0x049 (Xilinx), part: 0x362d, ver: 0x0)

   - Additionally, the board's LEDs should show the sequentially ordered numbers
     displayed in the binary form:

   .. image:: ../images/counter-example-arty.gif
      :align: center

7. LiteX Linux Example
----------------------

The LiteX Linux Example consists of a Linux capable VexRiscv CPU design with
the bootloader that uploads the Linux images over the Ethernet and
boots the Linux kernel.

This example uses the TFTP server. It is assumed that the server is running
on port ``6069`` and uses ``/tftp`` directory. To install and configure the
server, follow the instructions in the :doc:`../howto/install-tftp-server`.

#. Generate the LiteX Linux example bitstream:

   .. code-block:: bash

      cd symbiflow-examples/examples/xc7/linux_litex_demo
      make

#. Change IP of your Ethernet interface to ``192.168.100.100`` which is expected
   by the LiteX bootloader

   .. tabs::

      .. group-tab:: Ubuntu

            - using netplan / GUI:

               - `How to configure static IP address on Ubuntu 20.04 Focal Fossa Desktop/Server
                 <https://linuxconfig.org/how-to-configure-static-ip-address-on-ubuntu-20-04-focal-fossa-desktop-server>`_
               - `How to configure static IP address on Ubuntu 18.04 Bionic Beaver Linux
                 <https://linuxconfig.org/how-to-configure-static-ip-address-on-ubuntu-18-04-bionic-beaver-linux>`_
#. Copy the Linux images from the example to the TFTP server
   directory (assumed `/tftp`):

   .. _linux-on-litex-vexriscv: https://github.com/litex-hub/linux-on-litex-vexriscv

   .. code-block:: bash

      TFTP_SERVER_DIR=/tftp
      cp buildroot/* ${TFTP_SERVER_DIR}/
      cp emulator/emulator.bin ${TFTP_SERVER_DIR}/

#. Connect to the board using UART over the USB cable.

   Note that after plugging the board, two additional devices should appear
   in the ``/dev/`` directory. One of them is responsible for the communication
   with the board over UART.

   - To connect to the board, open a second terminal instance and type:

      .. code-block:: bash

         picocom -b 115200 /dev/ttyUSB1 --imap lfcrlf

   - If the picocom is unable to connect to the board, change the device path:

      If the picocom produces the following error:

      .. code-block:: bash

         FATAL: cannot open /dev/ttyUSB1: No such file or directory

      You might want to change the ``/dev/ttyUSB1`` to another device path.
      To list all the ``ttyUSBx`` devices, you can use:

      .. code-block:: bash

         ls -la /dev/ | grep ttyUSB

   .. note:: If the picocom is unable to connect to any ``ttyUSBx`` device,
      you probably don't have appropriate user permissions. On Debian distributions,
      type the command below to add the user to the ``dialout`` group.
      This should resolve the missing permissions problem:

      .. code-block:: bash

         sudo usermod -a -G dialout `whoami`

      You can also run the ``picocom`` program using ``sudo``

#. Load the bitstream to the Arty Board

   In the previous terminal instance, used to build the example, type:

   .. code-block:: bash

      openocd -f ${INSTALL_DIR}/conda/share/openocd/scripts/board/digilent_arty.cfg -c "init; pld load 0 top.bit; exit"

#. Check if the design is working correctly.

   - You should observe the following line in the OpenOCD output

   .. code-block:: bash

      Info : JTAG tap: xc7.tap tap/device found: 0x0362d093 (mfg: 0x049 (Xilinx), part: 0x362d, ver: 0x0)

   - In the ``picocom`` terminal, you should observe the following output:

   .. thumbnail:: ../images/linux-example-console.gif
      :align: center
      :width: 80%

   - Additionally, two LED's on the board should be turned on

   .. image:: ../images/linux-example-arty.jpg
      :width: 49%
      :align: center
