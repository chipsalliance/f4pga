# Developer's notes

## Project's structure

The main script is in the `sfbuild.py` file.
`sf_cache.py` contains code needed for tracking modifications in the project.
`sf_ugly` contains some ugly workarounds.

There a are two python modules which are shared by the code of `sfbuild.py` and
_sfbuild modules_: `sf_common` and `sf_module`.

_sfbuild modules_ are extensions to the build system that wrap tools to be used
within _sfbuild_ and currently they are standalone executable scripts. All
_sfbuild modules_ are single python scripts located under directories that
follow `sf_*_modules/` pattern. So currently those are:

 * `sf_common_modules` - modules which can be shared by multiple platforms.
 * `sf_xc7_modules` - modules specific to xc7 flows.
 * `sf_quicklogic_modules` - modules specific to Quiclogic flows.

There's also a `docs` directory which you are probably aware of if you are reading
this. All the documentation regarding sfbuild goes here.

`platforms` direcotory contains JSON files with _platform flow definitions_.
Names of those files must follow `platform_name.json` pattern.

## Differnt subsystems and where to find them?

### Building and dependency resolution

All the code regarding dependency resolution is located in `sfbuild.py` file.
Take a look at the `Flow` class.

Most of the work is done in `Flow._resolve_dependencies` method. Basically it
performs a _DFS_ with _stages_ (instances of _sfbuild modules_) as its nodes
which are linked using symbolic names of dependencies on inputs and outputs.
It queries the modules for information regarding i/o (most importantly the paths
on which they are going to produce outputs), checks whether
their inputs are going to be satisfied, checks if dependencies were modified, etc.

The actual building is done using `Flow._build_dep` procedure. It uses a similar
_DFS_ approach to invoke modules and check their inputs and outputs.

### Modification tracking

Modification tracking is done by taking, comparing and keeping track of `adler32`
hashes of all dependencies. Each dependency has a set of hashes associted with it.
The reason for having multiple hashes is that a dependency may have multiple
"_consumers_", ie. _stages_ which take it as input. Each hash is associated with
particular consumer. This is necessary, because the system tries to avoid rebuilds
when possible and status of each file (modified/unmodified) may differ in regards
to individual stages.

Keeping track of status of each file is done using `SymbiCache` class, which is
defined in `sf_cache.py` file. `SymbiCache` is used mostly inside `Flow`'s methods.

### Module's internals and API

`sf_module` contains everything that is necessary to write a module.
Prticularly the `Module` and `ModuleContext` classes 
The `do_module` function currently servers as to create an instance of some
`Module`'s subtype and provide a _CLI_ interface for it.

The _CLI_ interface however, is not meant to be used by an end-user, especially
given that it reads JSON data from _stdin_. A wrapper for interfacing with modules
exists in `sfbuild.py` and it's called `_run_module`.

### Internal environmental variable system

_sfbuild_ exposes some data to the user as well as reads some using internal
environmental variables. These can be referenced by users in
_platform flow definitions_ and _project flow configurations_ using the
`${variable_name}` syntax when defining values. They can also be read inside
_sfbuild modules_ by accesing the `ctx.values` namespace.

The core of tis system is the `ResolutionEnvironemt` class which can be found
inside the `sf_common` module.

### Installation

Check `CMakeLists.txt`.

## TODO:

Therea re a couple things that need  some work:

### Urgent

* Full support for Quicklogic platforms.
* Testing XC7 projects with more sophisticated setups and PCF flows.

### Important

* Fix and refactor overloading mechanism in _platform flow definitions_ and
  _platform flow configurations_. Values in the global `values` dict should
  be overloaded by those in `values` dict under `module_options.stage_name`
  inside _platform flow definition_. Values in `platform flow configuration`
  should be imported from `platform flow definition` and then overloaded by
  entries in `values`, `platform_name.values`,
  `platform_name.stages.stage_name.values` dicts respectively.

* Define a clear specification for entries in _platform flow definitions_ and
  _platform flow configurations_. Which environmental variables can be accessed
  where, and when?

* Force "_on-demand_" outputs if they are required by another stage.
  This may require redesigning the "on-demand" feature, which currently works
  by producing a dependency if and only if the user explicitely provides the
  path. Otherwise the path is unknown.

* Make commenting style consistent

* Write more docs

### Not very important

* Extend the metadata system for modules, perhaps make it easier to use.

* Add missing metadata for module targets.

### Maybe possible in the future

* Generate platform defintions using CMake.

### Out of the current scope

* Change interfaces of some internal python scripts. This could lead to possibly
  merging some modules for XC7 and Quicklogic into one common module.

## Quicklogic

So far I've been trying to bring support to _EOS-S3_ platform with mixed results.
Some parts of upstream Symbiflow aren't there yet. The Quicklogic scripts are
incomplete.

The _k4n8_ family remains a mystery to me. There's zero information about any
other familiar that _PP3_ and _PP2_. Neither could I find example projects for that.
Symbiflow's website mentions that only briefly. Yosys complains about `_DLATCH_N_`
not being supported when I tried synthesisng anything. Possibly related to the fact
that there's no equivalent of `pp3_latches_map.v` for `k4n8/umc22` in
[Yosys](https://github.com/YosysHQ/yosys/tree/master/techlibs/quicklogic).

**UPDATE**: Finally got the ioplace stage to work. Pulling the Quicklogic fork was
necessary in order to progress. The Quicklogic EOS-S3 development is now moved into
`eos-s3` branch of my fork. 
Additionally The `chandalar.pcf` file in _symbiflow-examples_ seemed to be faulty.
The '()' parenthesis should be replaced by '[]' brackets.
I also tried to synthesize the `iir` project from `tool-perf`, but **VPR** seems
to be unable to fit it (at least on my installation of Symbiflow which at this point
is a bit old and heavily modified).

Here's a flow configuration I've used for `btn_counter` on `eos-s3`:

```json
{
    "dependencies": {
        "sources": ["btn_counter.v"],
        "synth_log": "${build_dir}/synth.log",
        "pack_log": "${build_dir}/pack.log"
    },
    "values": {
        "top": "top",
        "build_dir": "build/eos-s3"
    },

    "ql-eos-s3": {
        "dependencies": {
            "pcf": "chandalar.pcf",
            "build_dir": "${build_dir}"
        }
    }
}
```