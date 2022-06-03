# Developer's notes
##### Last update: 2022-05-06

:::{warning}
These notes are provided as-is and they shouldn't be treated as a full-blown accurate
documentation, but rather as a helpful resource for those who want to get involved with
development of _f4pga_. These are not updated regularly.

For more detailed, up-to-date information about the code, refer to the pydoc documentation.
:::

## Project's structure

* `__init__.py` contains the logic and entry point of the build system
* `argparser.py` contains boring code for CLI interface
* `cache.py` contains code needed for tracking modifications in the project.
* `common.py` contains code shared by the main utility and the modules
* `flow_config.py` contains code for reading and accessing flow definitions and configurations
* `module_inspector.py` contains utilities for inspecting I/O of modules
* `module_runner.py` contains code required to load modules at run-time
* `module.py` contains definitions required for writing and using f4pga modules
* `part_db.json` contains mappings from part names to platform names
* `setup.py` contains a package installation script
* `stage.py` contains classes relevant  to stage representation
* `modules` contains loadable modules
* `platforms` contains platform flow definitions

:::{important}
Through the codebase _f4pga_ (tool) might be often referenced as _sfbuild_.
Similarly, _F4PGA_ (toolchain) might get called _Symbiflow_.
This is due to the project being written back when _F4PGA_ was called _Symbiflow_.
:::

## Different subsystems and where to find them?

### Building and dependency resolution

All the code regarding dependency resolution is located in `__init__.py` file.
Take a look at the `Flow` class.

Most of the work is done in `Flow._resolve_dependencies` method. Basically it
performs a _DFS_ with _stages_ (instances of _f4pga modules_) as its nodes
which are linked using symbolic names of dependencies on inputs and outputs.
It queries the modules for information regarding i/o (most importantly the paths
on which they are going to produce outputs), checks whether
their inputs are going to be satisfied, checks if dependencies were modified, etc.

The actual building is done using `Flow._build_dep` procedure. It uses a similar
_DFS_ approach to invoke modules and check their inputs and outputs.

### Modification tracking

Modification tracking is done by taking, comparing and keeping track of `adler32`
hashes of all dependencies. Each dependency has a set of hashes associated with it.
The reason for having multiple hashes is that a dependency may have multiple
"_consumers_", ie. _stages_ which take it as input. Each hash is associated with
particular consumer. This is necessary, because the system tries to avoid rebuilds
when possible and status of each file (modified/unmodified) may differ in regards
to individual stages.

Keeping track of status of each file is done using `F4Cache` class, which is
defined in `cache.py` file. `F4Cache` is used mostly inside `Flow`'s methods.

### Internal environmental variable system

_f4pga_ exposes some data to the user as well as reads some using internal
environmental variables. These can be referenced by users in
_platform flow definitions_ and _project flow configurations_ using the
`${variable_name}` syntax when defining values. They can also be read inside
_f4pga modules_ by accessing the `ctx.values` namespace.

The core of its system is the `ResolutionEnvironemt` class which can be found
inside the `common` module.

### Installation

Check `CMakeLists.txt`.

## TODO:

* Define a clear specification for entries in _platform flow definitions_ and
  _platform flow configurations_. Which environmental variables can be accessed
  where, and when?

* Force "_on-demand_" outputs if they are required by another stage.
  This may require redesigning the "on-demand" feature, which currently works
  by producing a dependency if and only if the user explicitly provides the
  path. Otherwise the path is unknown.

* Make commenting style consistent

* Document writing flow definitions

* Extend the metadata system for modules, perhaps make it easier to use.

* Add missing metadata for module targets.

* (_suggestion_) Generate platform definitions using CMake.

### Out of the current scope

* Change interfaces of some internal python scripts. This could lead to possibly
  merging some modules for XC7 and Quicklogic into one common module.
