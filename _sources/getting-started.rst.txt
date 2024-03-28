Getting started
###############

To begin using F4PGA, you might want to take a look at the :ref:`GettingStarted:Guidelines` below, which make for a good
starting point.
They will guide you through the process of installing and using the flows, explaining how to generate and load a
bitstream into your FPGA.

F4PGA flows are composed of multiple tools, scripts and CLI utilities.
Fortunately, various alternatives exist for setting up the whole ecosystem without going through the daunting task of
installing pieces one-by-one.
See :ref:`GettingStarted:ToolchainInstallation` below.

.. _GettingStarted:Guidelines:

Guidelines
==========

This is the main documentation, which gathers info about the :ref:`Python CLI tools and APIs <pyF4PGA>` and the
:ref:`Design Flows <Flows>` supported by F4PGA, along with a :ref:`Glossary`, references to specifications, plugins and
:ref:`publications <References>`.

Since F4PGA is meant for users with varying backgrounds and expertise, three paths are provided to walk into the ecosystem.

**Newcomers** are invited to go through `Examples ➚ <https://f4pga-examples.readthedocs.io>`__, which provides
step-by-step guidelines to install the tools through `Conda ➚ <https://conda.io>`__, generate a bitstream from one of the
provided designs and load the bitstream into a development board.
See :ref:`examples:CustomizingMakefiles` for adapting the build plumbing to your own desings.

For **Intermediate** users and contributors, who are already familiar with installing the tools and building bitstreams,
it is recommended to read the shell scripts in subdir :ghsrc:`scripts`, as well as the Continuous Integration
:ghsrc:`Pipeline <.github/workflows/Pipeline.yml>`.
Moreover, workflow `containers-conda-f4pga.yml <https://github.com/hdl/packages/blob/main/.github/workflows/containers-conda-f4pga.yml>`__
in :gh:`hdl/packages` shows how to use the ``*/conda/f4pga/*`` containers from :gh:`hdl/containers`
(see `workflow runs <https://github.com/hdl/packages/actions/workflows/containers-conda-f4pga.yml>`__ and
:ref:`GettingStarted:ToolchainInstallation:Other:Containers`).

**Advanced** users and developers willing to support new devices and/or enhance the features of the supported families
(see `F4PGA Architectures Visualizer ➚ <https://chipsalliance.github.io/f4pga-database-visualizer/>`__)
should head to `Architecture Definitions ➚ <https://f4pga.readthedocs.io/projects/arch-defs>`__.
The effort to document the details of each device/family are distributed on multiple projects:

* `Project X-Ray ➚ <https://f4pga.readthedocs.io/projects/prjxray/en/latest/>`__

  * `X-Ray Quickstart ➚ <https://f4pga.readthedocs.io/projects/prjxray/en/latest/db_dev_process/readme.html#quickstart-guide>`__

* `Project Trellis ➚ <https://prjtrellis.readthedocs.io/en/latest/>`__

* :gh:`Project Icestorm ➚ <f4pga/icestorm>`


.. _GettingStarted:ToolchainInstallation:

Toolchain installation
======================

F4PGA flows require multiple radpidly moving tools, assets and scripts, which makes it difficult for system packagers to
catch up.
Although some of the tools used in F4PGA (such as yosys, nextpnr or vpr) are available already through ``apt``, ``dnf``,
``pacman``, etc. they typically use pinned versions which are not the latest.
Therefore, the recommended installation procedure to follow the guidelines in F4PGA is repositories is using `Conda ➚ <https://conda.io>`__,
or some other pre-packaged solution combining latest releases.


.. _GettingStarted:ToolchainInstallation:Conda:

Conda (Recommended)
-------------------

.. IMPORTANT::
  Due to size constraints, Architecture Definition packages cannot be distributed through Conda.
  Hence, installing a functional F4PGA system is a two step process: bootstraping the conda environment and getting the
  tarballs (or vice versa).
  In the future, getting and managing the tarballs might be handled by F4PGA.

In coherence with the :ref:`GettingStarted:Guidelines` above, multiple Conda environments are provided:

* **Newcomers** will find environment and requirements files in :gh:`chipsalliance/f4pga-examples`, which are to be used
  as explained in :ref:`examples:Getting`.

* **Intermediate** users and contributors can use the minimal environment and requirements files included in the
  Architecture Definition packages, as is done in the CI of this repository.

* **Advanced** users and developers will get all the dependencies by bootstraping the environment in :gh:`SymbiFlow/f4pga-arch-defs`.

Summarizing, the installation procedure implies:

* Setting environment variables ``F4PGA_INSTALL_DIR`` and ``F4PGA_FAM`` (and optionally ``F4PGA_SHARE_DIR``), so that
  CLI utilities can find tools and assets.
* Downloading and extracting the Architecture Definition tarballs.
* Getting the environment and requirements files, by cloning f4pga-examples or f4pga-arch-defs, or by using the ones
  included in the tarballs.
* Bootstraping the Conda environment and optionally installing additional tools.

.. NOTE::
  Architecture Definition packages are built and released in :gh:`SymbiFlow/f4pga-arch-defs`.
  In this repository and in :gh:`chipsalliance/f4pga-examples`, pinned versions of the packages are used.
  However, tracking the *latest* release is also supported.
  See :ref:`arch-defs:Packages`.


.. _GettingStarted:ToolchainInstallation:Conda:Bumping:

Bumping/overriding specific tools
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Find guidelines to tweak the Conda environment and to override specific tools at :ref:`conda-eda:Usage:Bumping`.

In order to bump the Architecture Definition packages to an specific version, check the TIMESTAMP and the commit hash in
the job named ``GCS`` in a successful run of workflow :gh:`Automerge <SymbiFlow/f4pga-arch-defs/actions/workflows/Automerge.yml>`
on branch ``main`` of :gh:`SymbiFlow/f4pga-arch-defs`.
Alternatively, use the latest as explained in :ref:`arch-defs:Packages`.


.. _GettingStarted:ToolchainInstallation:Other:

Other
-----

Apart from Conda, multiple other solutions exist for setting up all the tools required in F4PGA.
:gh:`hdl/packages` *is an index for several projects providing great prepackaged/prebuilt and easy-to-set-up
bleeding-edge packages/environments of electronic design automation (EDA) tools/projects*.


.. _GettingStarted:ToolchainInstallation:Other:Containers:

Containers
~~~~~~~~~~

Ready-to-use docker/podman containers are maintained in :gh:`hdl/containers` and made available through
`gcr.io/hdl-containers` or `ghcr.io/hdl/containers`.
Some of those include Conda, the Architecture Definitions and the f4pga Python package, so they are ready to use along
with the examples in :gh:`chipsalliance/f4pga-examples`.
See :ref:`containers:tools-and-images:f4pga`.

.. HINT::
  :ghsharp:`574` is work in progress to provide an F4PGA Action
  (see `Understanding GitHub Actions <https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions>`__)
  based on ``*/conda/f4pga/*`` containers.


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
