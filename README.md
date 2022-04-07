# FOSS Flows For FPGA (F4PGA) project

<p align="center">
  <a title="Website" href="https://f4pga.org"><img src="https://img.shields.io/website?longCache=true&style=flat-square&label=f4pga.org&up_color=10cfc9&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga.org%2Findex.html&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTYiIGhlaWdodD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNNCAxMy41NjRMOC4xNzUgMTZ2LTQuODc3TDQgOC42ODh2NC44NzZ6bTAtNS42NTlWMy4wMjhsNC4xNzUgMi40MzV2NC44NzdMNCA3LjkwNXptNC44NTIgMi40MzVsMy44NDEtMi4yNDEtMy44NDEtMi4yNDF2NC40ODJ6bS0uMzM5LTUuNDYzbDQuMTgtMi40MzlMOC41MTMgMGwtNC4xOCAyLjQzOCA0LjE4IDIuNDM5eiIgZmlsbD0iIzEwQ0ZDOSIvPjwvc3ZnPg==&labelColor=fff"></a><!--
  -->
  <a title="Community" href="https://f4pga.readthedocs.io/en/latest/community.html#communication"><img src="https://img.shields.io/badge/Chat-IRC%20%7C%20Slack-white?longCache=true&style=flat-square&logo=Slack&logoColor=fff"></a><!--
  -->
  <a title="'Doc' workflow status" href="https://github.com/chipsalliance/f4pga/actions/workflows/Doc.yml"><img alt="'Doc' workflow status" src="https://img.shields.io/github/workflow/status/chipsalliance/f4pga/Docs/main?longCache=true&style=flat-square&label=Doc&logo=Github%20Actions&logoColor=fff"></a><!--
  -->
</p>

This is the top-level repository for the [F4PGA](https://f4pga.org/) project, which is a Workgroup under the [CHIPS Alliance](https://chipsalliance.org).
The elements of the project include (but are not limited to):

* The F4PGA open source FPGA toolchains for programming FPGAs (formerly known as [SymbiFlow](https://github.com/SymbiFlow)).
  This includes:

  * [![Documentation](https://img.shields.io/website?longCache=true&style=flat-square&label=Documentation&up_color=1226aa&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga.readthedocs.io%2Fen%2Flatest%2Findex.html&logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjxzdmcKICAgd2lkdGg9IjE2IgogICBoZWlnaHQ9IjE2IgogICB2aWV3Qm94PSIwIDAgMTYgMTYiCiAgIGZpbGw9Im5vbmUiCiAgIHZlcnNpb249IjEuMSIKICAgaWQ9InN2ZzQiCiAgIHNvZGlwb2RpOmRvY25hbWU9ImZhdmljb24uc3ZnIgogICBpbmtzY2FwZTp2ZXJzaW9uPSIxLjEuMiAoMGEwMGNmNTMzOSwgMjAyMi0wMi0wNCkiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGRlZnMKICAgICBpZD0iZGVmczgiIC8+CiAgPHNvZGlwb2RpOm5hbWVkdmlldwogICAgIGlkPSJuYW1lZHZpZXc2IgogICAgIHBhZ2Vjb2xvcj0iIzUwNTA1MCIKICAgICBib3JkZXJjb2xvcj0iI2ZmZmZmZiIKICAgICBib3JkZXJvcGFjaXR5PSIxIgogICAgIGlua3NjYXBlOnBhZ2VzaGFkb3c9IjAiCiAgICAgaW5rc2NhcGU6cGFnZW9wYWNpdHk9IjAiCiAgICAgaW5rc2NhcGU6cGFnZWNoZWNrZXJib2FyZD0iMSIKICAgICBzaG93Z3JpZD0iZmFsc2UiCiAgICAgaW5rc2NhcGU6em9vbT0iMzEuNzc1NjExIgogICAgIGlua3NjYXBlOmN4PSI4LjAwOTI4NzQiCiAgICAgaW5rc2NhcGU6Y3k9IjcuOTkzNTUyIgogICAgIGlua3NjYXBlOndpbmRvdy13aWR0aD0iMTkyMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctaGVpZ2h0PSIxMDE3IgogICAgIGlua3NjYXBlOndpbmRvdy14PSItOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iLTgiCiAgICAgaW5rc2NhcGU6d2luZG93LW1heGltaXplZD0iMSIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJzdmc0IiAvPgogIDxwYXRoCiAgICAgZD0iTTQgMTMuNTY0TDguMTc1IDE2di00Ljg3N0w0IDguNjg4djQuODc2em0wLTUuNjU5VjMuMDI4bDQuMTc1IDIuNDM1djQuODc3TDQgNy45MDV6bTQuODUyIDIuNDM1bDMuODQxLTIuMjQxLTMuODQxLTIuMjQxdjQuNDgyem0tLjMzOS01LjQ2M2w0LjE4LTIuNDM5TDguNTEzIDBsLTQuMTggMi40MzggNC4xOCAyLjQzOXoiCiAgICAgZmlsbD0iIzEwQ0ZDOSIKICAgICBpZD0icGF0aDIiCiAgICAgc3R5bGU9ImZpbGw6IzEyMjZhYTtmaWxsLW9wYWNpdHk6MSIgLz4KPC9zdmc+Cg==&labelColor=fff)](https://f4pga.readthedocs.io)
  * F4PGA Architecture Definitions [![Arch-Defs (for Developers)](https://img.shields.io/website?longCache=true&style=flat-square&label=For%20Developers&up_color=231f20&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga.readthedocs.io%2Fprojects%2Farch-defs%2Fen%2Flatest%2Findex.html&logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjxzdmcKICAgd2lkdGg9IjE2IgogICBoZWlnaHQ9IjE2IgogICB2aWV3Qm94PSIwIDAgMTYgMTYiCiAgIGZpbGw9Im5vbmUiCiAgIHZlcnNpb249IjEuMSIKICAgaWQ9InN2ZzQiCiAgIHNvZGlwb2RpOmRvY25hbWU9ImZhdmljb24uc3ZnIgogICBpbmtzY2FwZTp2ZXJzaW9uPSIxLjEuMiAoMGEwMGNmNTMzOSwgMjAyMi0wMi0wNCkiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGRlZnMKICAgICBpZD0iZGVmczgiIC8+CiAgPHNvZGlwb2RpOm5hbWVkdmlldwogICAgIGlkPSJuYW1lZHZpZXc2IgogICAgIHBhZ2Vjb2xvcj0iIzUwNTA1MCIKICAgICBib3JkZXJjb2xvcj0iI2ZmZmZmZiIKICAgICBib3JkZXJvcGFjaXR5PSIxIgogICAgIGlua3NjYXBlOnBhZ2VzaGFkb3c9IjAiCiAgICAgaW5rc2NhcGU6cGFnZW9wYWNpdHk9IjAiCiAgICAgaW5rc2NhcGU6cGFnZWNoZWNrZXJib2FyZD0iMSIKICAgICBzaG93Z3JpZD0iZmFsc2UiCiAgICAgaW5rc2NhcGU6em9vbT0iMzEuNzc1NjExIgogICAgIGlua3NjYXBlOmN4PSI4LjAwOTI4NzQiCiAgICAgaW5rc2NhcGU6Y3k9IjcuOTkzNTUyIgogICAgIGlua3NjYXBlOndpbmRvdy13aWR0aD0iMTkyMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctaGVpZ2h0PSIxMDE3IgogICAgIGlua3NjYXBlOndpbmRvdy14PSItOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iLTgiCiAgICAgaW5rc2NhcGU6d2luZG93LW1heGltaXplZD0iMSIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJzdmc0IiAvPgogIDxwYXRoCiAgICAgZD0iTTQgMTMuNTY0TDguMTc1IDE2di00Ljg3N0w0IDguNjg4djQuODc2em0wLTUuNjU5VjMuMDI4bDQuMTc1IDIuNDM1djQuODc3TDQgNy45MDV6bTQuODUyIDIuNDM1bDMuODQxLTIuMjQxLTMuODQxLTIuMjQxdjQuNDgyem0tLjMzOS01LjQ2M2w0LjE4LTIuNDM5TDguNTEzIDBsLTQuMTggMi40MzggNC4xOCAyLjQzOXoiCiAgICAgZmlsbD0iIzEwQ0ZDOSIKICAgICBpZD0icGF0aDIiCiAgICAgc3R5bGU9ImZpbGw6IzIzMWYyMDtmaWxsLW9wYWNpdHk6MSIgLz4KPC9zdmc+Cg==&labelColor=fff)](https://f4pga.readthedocs.io/projects/arch-defs)
  * F4PGA Examples [![Examples (for Users)](https://img.shields.io/website?longCache=true&style=flat-square&label=For%20Users&up_color=white&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga-examples.readthedocs.io%2Fen%2Flatest%2Findex.html&logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjxzdmcKICAgd2lkdGg9IjE2IgogICBoZWlnaHQ9IjE2IgogICB2aWV3Qm94PSIwIDAgMTYgMTYiCiAgIGZpbGw9Im5vbmUiCiAgIHZlcnNpb249IjEuMSIKICAgaWQ9InN2ZzQiCiAgIHNvZGlwb2RpOmRvY25hbWU9ImZhdmljb24uc3ZnIgogICBpbmtzY2FwZTp2ZXJzaW9uPSIxLjEuMiAoMGEwMGNmNTMzOSwgMjAyMi0wMi0wNCkiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGRlZnMKICAgICBpZD0iZGVmczgiIC8+CiAgPHNvZGlwb2RpOm5hbWVkdmlldwogICAgIGlkPSJuYW1lZHZpZXc2IgogICAgIHBhZ2Vjb2xvcj0iIzUwNTA1MCIKICAgICBib3JkZXJjb2xvcj0iI2ZmZmZmZiIKICAgICBib3JkZXJvcGFjaXR5PSIxIgogICAgIGlua3NjYXBlOnBhZ2VzaGFkb3c9IjAiCiAgICAgaW5rc2NhcGU6cGFnZW9wYWNpdHk9IjAiCiAgICAgaW5rc2NhcGU6cGFnZWNoZWNrZXJib2FyZD0iMSIKICAgICBzaG93Z3JpZD0iZmFsc2UiCiAgICAgaW5rc2NhcGU6em9vbT0iMzEuNzc1NjExIgogICAgIGlua3NjYXBlOmN4PSI4LjAwOTI4NzQiCiAgICAgaW5rc2NhcGU6Y3k9IjcuOTkzNTUyIgogICAgIGlua3NjYXBlOndpbmRvdy13aWR0aD0iMTkyMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctaGVpZ2h0PSIxMDE3IgogICAgIGlua3NjYXBlOndpbmRvdy14PSItOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iLTgiCiAgICAgaW5rc2NhcGU6d2luZG93LW1heGltaXplZD0iMSIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJzdmc0IiAvPgogIDxwYXRoCiAgICAgZD0iTTQgMTMuNTY0TDguMTc1IDE2di00Ljg3N0w0IDguNjg4djQuODc2em0wLTUuNjU5VjMuMDI4bDQuMTc1IDIuNDM1djQuODc3TDQgNy45MDV6bTQuODUyIDIuNDM1bDMuODQxLTIuMjQxLTMuODQxLTIuMjQxdjQuNDgyem0tLjMzOS01LjQ2M2w0LjE4LTIuNDM5TDguNTEzIDBsLTQuMTggMi40MzggNC4xOCAyLjQzOXoiCiAgICAgZmlsbD0iIzEwQ0ZDOSIKICAgICBpZD0icGF0aDIiCiAgICAgc3R5bGU9ImZpbGw6I2ZmZmZmZjtmaWxsLW9wYWNpdHk6MSIgLz4KPC9zdmc+Cg==&labelColor=231f20)](https://f4pga-examples.readthedocs.io)
  * [F4PGA Yosys plugins](https://github.com/chipsalliance/yosys-f4pga-plugins)

* The FPGA interchange format (an interchange format defined by CHIPS Alliance to enable interoperability between
  different FPGA tools) adopted by the F4PGA toolchain:

  * [FPGA Interchange schema](https://github.com/chipsalliance/fpga-interchange-schema)
  * [FPGA Interchange Python utilities](https://github.com/chipsalliance/python-fpga-interchange)
  * [FPGA Interchange Test suite](https://github.com/SymbiFlow/fpga-interchange-tests)

* The [FPGA tool performance framework](https://github.com/chipsalliance/fpga-tool-perf) framework for benchmarking
  designs against various FPGA tools, and vice versa, over time.

* FPGA Database visualisation tools for visual exploration of FPGA bitstream and databases:

  * [F4PGA bitstream viewer](https://github.com/SymbiFlow/f4pga-bitstream-viewer)
  * [F4PGA database visualizer](https://github.com/chipsalliance/f4pga-database-visualizer)

* Other utilities (FPGA assembly format, documentation and other):

  * [F4PGA Assembly (FASM)](https://github.com/chipsalliance/fasm)
  * [Xilinx bitstream generation library](https://github.com/SymbiFlow/f4pga-xc-fasm)
  * [Verilog-to-routing XML utilities](https://github.com/SymbiFlow/vtr-xml-utils)
  * [SDF format utilities](https://github.com/chipsalliance/python-sdf-timing)
  * [F4PGA tools data manager](https://github.com/SymbiFlow/symbiflow-tools-data-manager)
  * [F4PGA Sphinx Theme](https://github.com/SymbiFlow/sphinx_symbiflow_theme)
  * [F4PGA Sphinx HDL diagrams](https://github.com/SymbiFlow/sphinxcontrib-hdl-diagrams)
  * [F4PGA Sphinx Verilog domain](https://github.com/SymbiFlow/sphinx-verilog-domain)

## F4PGA Workgroup

The F4PGA Workgroup consists of members from different backgrounds, including FPGA vendors
([Xilinx](https://www.xilinx.com/) and [QuickLogic](https://www.quicklogic.com/)),
industrial users
([Google](https://www.google.com/), [Antmicro](https://antmicro.com/))
and academia
([University of Toronto](https://www.utoronto.ca/)),
who collaborate to build a more open source and software-driven FPGA ecosystem (IP, tools and workflows) to drive the
adoption of FPGAs in existing and new use cases, and eliminate barriers of entry.
