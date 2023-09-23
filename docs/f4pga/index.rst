.. _pyF4PGA:

Overview
########

Python F4PGA is a package containing multiple modules to facilitate the usage of all the tools integrated in the F4PGA
ecosystem, and beyond.
The scope of Python F4PGA is threefold:

* Provide a fine-grained *pythonic* interface to the tools and utilities available as either command-line interfaces
  (CLIs) or application proggraming interfaces (APIs) (either web or through shared libraries).

* Provide a unified CLI front-end covering the whole flows for end-users to produce bitstreams from HDL and/or software sources.
  It's meant as a future replacement of the deprecated ``symbiflow_*`` shell scripts.

* Provide a CLI entrypoint for developers contributing to bitstream documentation and testing (continuous integration).

.. ATTENTION::
  This is work-in-progress to adapt and organize the existing shell/bash based plumbing from multiple F4PGA repositories.
  Therefore, it's still a *pre-alpha* and the codebase, commands and flows are subject to change.
  It is strongly suggested not to rely on Python F4PGA until this note is updated/removed.

``f4pga`` contains *EDA* tool wrappers that provide meta-data about the tools, utilities related to tracking files and
inspection of data used within the flows, scripts used by tools within flows, a dependency resolution algorithm and flow
templates for various devices.

The basic usage requires creation of a ``flow.json`` file describing the FPGA-oriented project.
See, for instance, example :gh:`xc7/counter_test/flow.json ➚ <chipsalliance/f4pga-examples/blob/main/xc7/counter_test/flow.json>`.
Alternatively the flow can be configured through CLI arguments only.

With a given flow configuration, run ``f4pga build -f flow.json`` builds the default target.

See :doc:`Usage` to learn more about ``f4pga``.
