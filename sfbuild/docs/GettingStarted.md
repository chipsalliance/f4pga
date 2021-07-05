# sfbuild

## Getting started

To use _**sfbuild**_ you need a working python 3 installation which should be icluded
as a part of conda virtual environment set up during symbiflow installation.
_**sfbuild**_ installs along _**Symbiflow**_ with any version of toolchain. However,
only _XC7_ architectures are supported currently and _Quicklogic_ support is a work
in progress. _**sfbuild**_'s installation directory is `bin/sfbuild`, under your
_**Symbiflow**_ installation directory. `sfbuild.py` is the script that you should
run to use _**sfbuild**_.

To get started with a project that already uses sfbuild, go to the project's
directory and run the following line to build a bitstream:
```
$ python3 /path/to/sfbuild.py flow.json -p platform_name -t bitstream
```

Substitute `platform_name` by the name of the target platform (eg. `x7a50t`).
`flow.json` should be a **project's flow configuration** file included with the
project. If you are unsure if you got the right file, you can check an example of
the contents of such file shown in the "_Using sfbuild to build a target_" section.

The location of the file containing bitstream will be indicated by sfbuild after the
flow completes. Look for a line like this one on stdout.:

```
Target `bitstream` -> build/arty_35/top.bit
```

-------------------------------------------------------------------------------------

## Fundamental concepts

If you want to create a new sfbuild project, it's highly recommended that you
read this section first.

### sfbuild

_**sfbuild**_ is a modular build system designed to handle various
_Verilog-to-bitsream_ flows for FPGAs. It works by wrapping the necessary tools
in python scripts, which are called **sfbuild modules**. The modules are then
referenced in a **platform's flow definition** files along configurations specific
for given platform. These files for come included as a part of _**sfbuild**_ for the
following platforms:

* x7a50t
* x7a100t
* x7a200t (_soon_)

You can also write your own **platform's flow definition** file if you want to bring
support to a different device.

Each project that uses _**sfbuild**_ to perform any flow should include a _.json_
file describing the project. The purpose of that file is to configure inputs
for the flow and possibly override configuration values if necessary.

### Modules

A **module** (also referred to as **sfbuild module** in sistuations where there might
be confusion between Python's _modules_ and sfbuild's _modules_) is a python scripts
that wraps a tool used within **Symbilfow's** ecosystem. The main purpouse of this
wrapper is to provide a unified interface for sfbuild to use and configure the tool
as well as provide information about files required and produced by the tool.

### Dependecies

A **dependency** is any file, directory or a list of such that a **module** takes as
its input or produces on its output. 

Modules specify their dependencies by using symbolic names instead of file paths.
The files they produce are also given symbolic names and paths which are either set
through **project's flow configuration** file or derived from the paths of the
dependencies taken by the module.

### Target

**Target** is a dependency that the user has asked sfbuild to produce.

### Flow

A **flow** is set of **modules** executed in a right order to produce a **target**.

### .symbicache

All **dependencies** are tracked by a modification tracking system which stores hashes
of the files (directories get always `'0'` hash) in `.symbicache` file in the root of
the project. When _**sfbuild**_ constructs a **flow**, it will try to omit execution
of modules which would receive the same data on their input. There's a strong
_assumption_ there that a **module**'s output remains unchanged if the input
doconfiguring esn't
change, ie. **modules** are deterministic.

### Resolution

A **dependency** is said to be **resolved** if it meets one of the following
critereia:

* it exists on persistent storage and its hash matches the one stored in .symbicache
* there exists such **flow** that all of the dependieces of its modules are
  **resolved** and it produces the **dependency** in question.

### Platform's flow definition

**Platform's flow definition** is a piece of data describing a space of flows for a
given platform, serialized into a _JSON_.
It's stored in a file that's named after the device's name under `sfbuild/platforms`.

**Platform's flow definition** contains a list of modules available for constructing
flows and defines a set of values which the modules can reference. In case of some
modules it  may also define a set of parameters used during their construction.
`mkdirs` module uses that to allow production of of multiple directories as separate
dependencies. This however is an experimental feature which possibly will be
removed in favor of having multiple instances of the same module with renameable
ouputs.

Not all **dependencies** have to be **resolved** at this stage, a **platform's flow
definition** for example won't be able to provide a list of source files needed in a
**flow**.

### Projects's flow configuration

Similarly to **platform's flow definition**, **Projects's flow configuration** is a
_JSON_ that is used to configure **modules**. There are however a couple differences
here and there.

* The most obvious one is that this file is unique for a project and
  is provided by the user of _**sfbuild**_.

* The other difference is that it doesn't list **modules** available for the
  platform.

* All the values provided in **projects's flow configuration** will override those
  provided in **platform's flow definition**.

* It can contain sections with configurations for different platforms.

* Unlike **platform's flow definition** it can give explicit paths to dependencies.

* At this stage all mandatory **dependencies** should be resolved.

Typically **projects's flow configuration** will be used to resolve dependencies
for _HDL source code_ and _device constraints_.

## Using sfbuild to build a target

To build a **target** "`target_name`", use the following command:
```
$ python3 /path/to/sfbuild.py flow.json -p platform_device_name -t target_name
```
where `flow.json` is a path to **projects's flow configuration**

For example, let's consider the following
**projects's flow configuration (flow.json)**:

```json
{
    "dependencies": {
        "sources": ["counter.v"],
        "xdc": ["arty.xdc"],
        "synth_log": "synth.log",
        "pack_log": "pack.log",
        "top": "top"
    },
    "xc7a50t": {
        "dependencies": {
            "build_dir": "build/arty_35"
        }
    }
}
```

It specifies list of paths to Verilog source files as "`sources`" dependency.
Similarily it also provides an "`XDC`" file with constrains. ("`xdc`" dependency)

It also names a path for synthesis and logs ("`synth_log`", "`pack_log`").
These two are optional on-demand outputs, meaning they won't be produces unless
their paths are explicitely set.

"`top`" value is set to in order to specify the name of top Verilog module, which
is required during synthesis.

"`build_dir`" is an optional helper dependency. When available, modules will put
their outputs into that directory. It's also an _on-demand_ output of `mkdirs`
module in _xc7a50t_ flow definition, which means that if specified directory does
not exist, `mkdirs` will create it and provide as `build_dir` dependency.

building a bitstream for *x7a50t* would look like that:

With this flow configuration, you can build a bitstream for arty_35 using the
following command: 

```
$ python3 /path/to/sfbuild.py flow.json -p x7a50t -t bitstream
```

### Pretend mode

You can also add a `--pretend` (`-P`) option if you just want to see the results of
dependency resolution for a specified target without building it. This is useful
when you just want to know what files will be generated and where wilh they be
stored.

### Info mode

Modules have the ability to include description to the dependencies they produce.

Running _**sfbuild**_ with `--info` (`-i`) flag allows youn to see descriptions of
these dependencies. This option doesn't require a target to be specified, but you
still have to provuide a flow configuration and platform name.

This is still an experimental option, most targets currently lack descriptions
and no information whether the output is _on-demand_ is currently displayed.

Example:
```
$ python3 /path/to/sfbuild.py flow.json -p x7a50t -i
```
```
Platform dependencies/targets:
    build_dir:          <no descritption>
                        module: `mk_build_dir`
    eblif:              Extended BLIF hierarchical sequential designs file
                        generated by YOSYS
                        module: `synth`
    fasm_extra:         <no description>
                        module: `synth`
    json:               JSON file containing a design generated by YOSYS
                        module: `synth`
    synth_json:         <no description>
                        module: `synth`
    sdc:                <no description>
                        module: `synth`
```

_This is only a snippet of the entire output_

### Summary of all available sfbuild options

| long       | short | arguments              | description                                     |
|------------|:-----:|------------------------|-------------------------------------------------|
| --platform | -p    | device name            | Specify target device name (eg. x7a100t)        |
| --target   | -t    | target dependency name | Specify target to produce                       |
| --info     | -i    | -                      | Display information about available targets     |
| --pretend  | -P    | -                      | Resolve dependencies without executing the flow |

### Dependency resolution display

sfbuild displays some information about dependencies when requesting a target.

Here's an example of a possible output when trying to build `bitstream` target:
```
sfbuild: Symbiflow Build System
Scanning modules...

Project status:
    [R] bitstream:  bitstream -> build/arty_35/top.bit
    [O] build_dir:  build/arty_35
    [R] eblif:  synth -> build/arty_35/top.eblif
    [R] fasm:  fasm -> build/arty_35/top.fasm
    [R] fasm_extra:  synth -> build/arty_35/top_fasm_extra.fasm
    [R] io_place:  ioplace -> build/arty_35/top.ioplace
    [R] net:  pack -> build/arty_35/top.net
    [X] pcf:  MISSING
    [R] place:  place -> build/arty_35/top.place
    [R] place_constraints:  place_constraints -> build/arty_35/top.preplace
    [R] route:  route -> build/arty_35/top.route
    [R] sdc:  synth -> build/arty_35/top.sdc
    [N] sources:  ['counter.v']
    [O] xdc:  ['arty.xdc']

sfbuild: DONE
```

The letters in the boxes describe the status of a dependency which's name is next
to the box.

 * **X** - dependency unresolved. This isn't always a bad sign. Some dependencies
   are not required to, such as "`pcf`".
 * **U** - dependency unreachable. The dependency has a module that could produce
   it, but the module's dependencies are unresolved. This doesn't say whether the
   dependency was necessary or not.
 * **O** - dependency present, unchanged. This dependency is already built and is
   confirmed to stay unchanged during flow execution.
 * **N** - dependency present, new/changed. This dependency is already present on 
   the persistent storage, but it was either missing earlier, or
   its content changed from the last time.
   (WARNING: it won't continue to be reported as "**N**" after a successful build of
   any target. This may lead to some false "**O**"s in some complex scenarios. This
   should be fixed in the future.)
 * **S** - depenendency not present, resolved. This dependency is not
  currently available on the persistent storage, however it will be produced within
  flow's execution. 
 * **R** - depenendency present, resolved, requires rebuild. This dependency is
  currently available on the persistent storage, however it has to be rebuilt due
  to the changes in the project.

Additional info about a dependency will be displayed next to its name after a
colon:

* In case of dependencies that are to be built (**S**/**R**), there's a name of a
  module that will produce this dependency, followed by "`->`" and a path or list of
  paths to file(s)/directory(ies) that will be produced as this dependency.

* In case of dependencies which do not require execution of any modules, only
  a path or list of paths to file(s)/directory(ies) that will be displayed

* In case of unresolved dependencies (**X**), which are never produced by any
  module, a text sying "`MISSING`" will be displayed
* In case of unreachable dependencies, a name of such module  that could produce
  them will be displayed followed by "`-> ???`".

In the example above file `counter.v` has been modified and is now marked as
"**N**". This couses a bunch of other dependencies to be reqbuilt ("**R**").
`build_dir` and `xdc` were already present, so they are marked as "**O**".