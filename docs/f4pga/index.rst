.. _pyF4PGA:

Overview
########

Python F4PGA is a package containing multiple modules to facilitate the usage of all the tools integrated in the F4PGA
ecosystem, and beyond.
The scope of Python F4PGA is threefold:

* Provide a fine-grained *pythonic* interface to the tools and utilities available as either command-line interfaces
  (CLIs) or application proggraming interfaces (APIs) (either web or through shared libraries).
* Provide a CLI entrypoint covering the whole flows for end-users to produce bitstreams from HDL and/or software sources.
* Provide a CLI entrypoint for developers contributing to bitstream documentation and testing (continuous integration).

.. ATTENTION::
  This is work-in-progress to adapt and organize the existing shell/bash based plumbing from multiple F4PGA repositories.
  Therefore, it's still a *pre-alpha* and the codebase, commands and flows are subject to change.
  It is strongly suggested not to rely on Python F4PGA until this note is updated/removed.

References
==========

* :gh:`chipsalliance/fpga-tool-perf#390@issuecomment-1023487178 <chipsalliance/fpga-tool-perf/pull/390#issuecomment-1023487178>`
* :ghsharp:`2225`
* :ghsharp:`2371`
* :ghsharp:`2455`
* `F4PGA GSoC 2022 project ideas: Generalization of wrapper scripts for installed F4PGA toolchain and making them OS agnostic <https://github.com/f4pga/ideas/blob/master/gsoc-2022-ideas.md#generalization-of-wrapper-scripts-for-installed-f4pga-toolchain-and-making-them-OS-agnostic>`__
* :gh:`FuseSoc <olofk/fusesoc>` | :gh:`Edalize <olofk/edalize>`
* `Electronic Design Automation Abstraction (EDA²) <https://edaa-org.github.io/>`__
