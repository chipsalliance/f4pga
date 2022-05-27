# Usage

## Getting started

To use `f4pga` you need a working Python 3 installation which should be included as a part of the conda virtual
environment set up during F4PGA installation.
`f4pga` is installed together with F4PGA, regardless of the version of the toolchain.
However, only _XC7_ architectures are supported currently and _Quicklogic_ support is a work in progress.

To get started with a project that already uses `f4pga`, go to the project's directory and run the following line to
generate a bitstream:

```bash
$ f4pga build -f flow.json
```

`flow.json` should be a *project flow configuration* file included with the project.
If you are unsure if you got the right file, you can check an example of the contents of such file shown in the
*Build a target* section below.

The location of the bitstream will be indicated by `f4pga` after the flow completes.
Look for a line like this one on stdout:

```bash
Target `bitstream` -> build/arty_35/top.bit
```

## Fundamental concepts

If you want to create a new project, it's highly recommended that you read this section first.

### f4pga

`f4pga` is a modular build system designed to handle various _Verilog-to-bitstream_ flows for FPGAs.
It works by wrapping the necessary tools in Python, which are called *f4pga modules*.
Modules are then referenced in *platform flow definition* files, together with configuration specific for a given
platform.
Flow definition files for the following platforms are included as a part of _f4pga_:

* **AMD Xilinx x7a50t** (and architecturally equivalent devices, such as x7a35t)
* **AMD Xilinx x7a100t**
* **AMD Xilinx x7a200t**
* **Quicklogic EOS-S3** (currently unsupported, provided only for development purposes)
* **Quicklogic K4N8** (currently unsupported, provided only for development purposes)

You can also write your own *platform flow definition* file if you want to bring support for a different device.

Each project that uses `f4pga` to perform any flow should include a _.json_ file describing the project.
The purpose of that file is to configure inputs for the flow and override configuration values if necessary.

### Modules

A *module* (also referred to as *f4pga module* in situations where there might be confusion between arbitrary Python
_modules_ and f4pga _modules_) is a Python script that wraps a tool used within the F4PGA ecosystem.
The main purpose of the wrappers is to provide a unified interface for `f4pga` to use and to configure the tool,
as well as provide information about files required and produced by the tool.

### Dependencies

A *dependency* is any file, directory or a list of such that a *module* takes as its input or produces on its output.

Modules specify their dependencies by using symbolic names instead of file paths.
The files they produce are also given symbolic names and paths which are either set through *project flow configuration*
file or derived from the paths of the dependencies taken by the module.

### Target

*Target* is a dependency that the user has asked F4PGA to produce.

### Flow

A *flow* is set of *modules* executed in a right order to produce a *target*.

### .f4cache

All *dependencies* are tracked by a modification tracking system which stores hashes of the files
(directories get always `'0'` hash) in `.f4cache` file in the root of the project.
When F4PGA constructs a *flow*, it will try to omit execution of modules which would receive the same data on their
input.
There is a strong _assumption_ there that a *module*'s output remains unchanged if the input configuration isn't
changed, ie. *modules* are deterministic. This is might be not true for some tools and in case you really want to re-run
a stage, there's a `--nocache` option that treats the `.f4cache` file as if it was empty.

### Resolution

A *dependency* is said to be *resolved* if it meets one of the following criteria:

* it exists on persistent storage and its hash matches the one stored in .f4cache
* there exists such *flow* that all of the dependencies of its modules are *resolved* and it produces the *dependency* in
  question.

### Platform's flow definition

*Platform flow definition* is a piece of data describing a space of flows for a given platform, serialized into a _JSON_.
It's stored in a file that's named after the device's name under `f4pga/platforms`.

*Platform flow definition* contains a list of modules available for constructing flows and defines a set of values which
the modules can reference.
In case of some modules it may also define a set of parameters used during their construction.
`mkdirs` module uses that to allow production of of multiple directories as separate dependencies.
This however is an experimental feature which possibly will be removed in favor of having multiple instances of the same
module with renameable outputs.

Not all *dependencies** have to be *resolved* at this stage, a *platform's flow definition* for example won't be able to
provide a list of source files needed in a *flow*.

### Project's flow configuration

Similarly to *platform flow definition*, *Projects flow configuration* is a _JSON_ that is used to configure *modules*. There are however a couple differences here and there.

* The most obvious one is that this file is unique for a project and is provided by the user of `f4pga`.

* The other difference is that it doesn't list *modules* available for the platform.

* All the values provided in *projects flow configuration* will override those provided in *platform flow definition*.

* It can contain sections with configurations for different platforms.

* Unlike *platform flow definition* it can give explicit paths to dependencies.

* At this stage all mandatory *dependencies* should be resolved.

Typically *projects flow configuration* will be used to resolve dependencies for _HDL source code_ and _device constraints_.

## Build a target

### Using flow configuration file

To build a *target* `target_name`, use the following command:

```bash
$ f4pga build -f flow.json -p platform_device_name -t target_name
```
where `flow.json` is a path to *projects flow configuration*.

For example, let's consider the following *projects flow configuration (flow.json)*:

```json
{
    "default_part": "XC7A35TCSG324-1",
    "dependencies": {
        "sources": ["counter.v"],
        "xdc": ["arty.xdc"],
        "synth_log": "synth.log",
        "pack_log": "pack.log",
    },
    "values": {
        "top": "top"
    },
    "XC7A35TCSG324-1": {
        "default_target": "bitstream",
        "dependencies": {
            "build_dir": "build/arty_35"
        }
    }
}
```

It specifies list of paths to Verilog source files as `sources` dependency.
Similarly it also provides an `XDC` file with constrains (`xdc` dependency).

It also names a path for synthesis and logs (`synth_log`, `pack_log`).
These two are optional on-demand outputs, meaning they won't be produces unless their paths are explicitly set.

`top` value is set to in order to specify the name of top Verilog module, which is required during synthesis.

`build_dir` is an optional helper dependency.
When available, modules will put their outputs into that directory.
It's also an _on-demand_ output of `mkdirs` module in _xc7a50t_ flow definition, which means that if specified directory
does not exist, `mkdirs` will create it and provide as `build_dir` dependency.

With this flow configuration, you can build a bitstream for arty_35 using the
following command:

```
$ f4pga build -f flow.json -p XC7A35TCSG324-1 -t bitstream
```

Because we have `default_platform` defined, we can skip the `--part` argument.
We can also skip the `--target` argument because we have a `default_target` defined for the
chosen platform. This will default to the `bitstream` target of `xc7a50t` platform:

```
$ f4pga build -f flow.json
```

### Using Command-Line Interface

Alternatively you can use CLI to pass the configuration without creating a flow file:

```
$ f4pga build -p XC7A35TCSG324-1 -Dsources=[counter.v] -Dxdc=[arty.xdc] -Dsynth_log=synth.log -Dpack_log=pack.log -Dbuild_dir=build/arty_35 -Vtop=top -t bitstream
```

CLI flow configuration can be used alongside a flow configuration file and will override
conflicting dependencies/values from the file.

CLI configuration follows the following format:

`<dependency/value identifier>=<expression>` 

`<dependency/value identifier>` is the name of dependency or value optionally prefixed by a stage
name and a dot (`.`). Using the notation with stage name sets the dependency/value only for the
specified stage.

`<expression>` is a form of defining a dependency path or a value. Characters are interpreted
as strings unless the follow one of the following format:
* `[item1,item2,item3,...]` - this is a list of strings
* `{key1:value1,key2:value2,key3:value3,...}` - this is a dictionary

Nesting structures is currently unsupported in CLI.

### Pretend mode

You can also add a `--pretend` (`-P`) option if you just want to see the results of dependency resolution for a
specified target without building it.
This is useful when you just want to know what files will be generated and where will they be stored.

### Info mode

Modules have the ability to include description to the dependencies they produce.

Running `f4pga` with `--info` (`-i`) flag allows you to see descriptions of these dependencies.
This option doesn't require a target to be specified, but you still have to provide a flow configuration and platform
name.

This is still an experimental option, most targets currently lack descriptions and no information whether the output is
_on-demand_ is currently displayed.

Example:

```bash
$ f4pga -v build -f flow.json -p XC7A35TCSG324-1 -i
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

:::{important}
This is only a snippet of the entire output.
:::

### Summary of global options

| long      | short | arguments                | description                                                                |
|-----------|:-----:|--------------------------|----------------------------------------------------------------------------|
| --verbose | -v    | -                        | Control verbosity level. 0 for no verbose output. 2 for maximum verbosity  |
| --silent  | -s    | -                        | Suppress any output                                                        |

### Summary of all available sub-commands

| name    | description                 |
|---------|-----------------------------|
| build   | Build a project             |
| showd   | Print value of a dependency

### Summary of all options available for `build` sub-command

| long        | short | arguments                | description                                             |
|-------------|:-----:|--------------------------|---------------------------------------------------------|
| --flow      | -f    | flow configuration file  | Use flow configuration file                             |
| --part      | -p    | part name                | Specify target part name                                |
| --target    | -t    | target dependency name   | Specify target to produce                               |
| --info      | -i    | -                        | Display information about available targets             |
| --pretend   | -P    | -                        | Resolve dependencies without executing the flow         |
| --nocache   |       | -                        | Do not perform incremental build (do full a full build) |
| --stageinfo | -S    | stage name               | Display information about a specified stage             |
| --dep       | -D    | dependency_name=pathexpr | Add a dependency to configuration                       |
| --val       | -V    | value_name=valueexpr     | Add a value to configuration                            |

### Summary of all options available for `showd` sub-command

| long        | short | arguments                | description                                                 |
|-------------|:-----:|--------------------------|-------------------------------------------------------------|
| --flow      | -f    | flow configuration file  | Use flow configuration file                                 |
| --part      | -p    | part name                | Specify target part name                                    |
| --stage     | -s    | part name                | Specify stage name (to display stage-specific dependencies) |      

### Dependency resolution display

F4PGA displays some information about dependencies when requesting a target.

Here's an example of a possible output when trying to build `bitstream` target (use `-P`):

```
F4PGA Build System
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

f4pga: DONE
```

The letters in the boxes describe the status of a dependency whose name is next to the box.

 * **X** - dependency unresolved.
   Dependency is not present or cannot be produced.
   This isn't always a bad sign. Some dependencies are not required to, such as `pcf`.

 * **O** - dependency present, unchanged.
   This dependency is already built and is confirmed to stay unchanged during flow execution.

 * **N** - dependency present, new/changed.
   This dependency is already present on the persistent storage, but it was either missing earlier, or its content
   changed since the last time it was used.

   :::{warning}
   It won't continue to be reported as "**N**" after a successful build of any target.
   This may lead to some false "**O**"s in some complex scenarios.
   This should be fixed in the future.
   :::

 * **S** - dependency not present, resolved.
   This dependency is not currently available on the persistent storage, however it will be produced within flow's
   execution.

 * **R** - dependency present, resolved, requires rebuild.
  This dependency is currently available on the persistent storage, however it has to be rebuilt due to the changes in
  the project.

Additional info about a dependency will be displayed next to its name after a colon:

* In case of dependencies that are to be built (**S**/**R**), there's a name of a module that will produce this
  dependency, followed by `->` and a path or list of paths to file(s)/directory(ies) that will be produced as this
  dependency.

* In case of dependencies which do not require execution of any modules, only a path or list of paths to
  file(s)/directory(ies) that will be displayed.

* In case of unresolved dependencies (**X**), which are never produced by any module, a text saying "`MISSING`" will be
  displayed.

In the example above file `counter.v` has been modified and is now marked as "**N**".
This causes a bunch of other dependencies to be rebuilt ("**R**").
`build_dir` and `xdc` were already present, so they are marked as "**O**".

## Common targets and values

Targets and values are named with some conventions.
Below are lists of the target and value names along with their meanings.

### Need to be provided by the user

| Target name | list | Description |
|-------------|:----:|-------------|
| `sources` | yes | Verilog sources |
| `sdc` | no | Synopsys Design Constraints |
| `xdc` | yes | Xilinx Design Constraints (available only for Xilinx platforms) |
| `pcf` | no | Physical Constraints File |

### Available in most flows

| Target name  | list | Description                                                     |
|--------------|:----:|-----------------------------------------------------------------|
| `eblif`      | no   | Extended blif file                                              |
| `bitstream`  | no   | Bitstream                                                       |
| `net`        | no   | Netlist                                                         |
| `fasm`       | no   | Final FPGA Assembly                                             |
| `fasm_extra` | no   | Additional FPGA assembly that may be generated during synthesis |
| `build_dir`  | no   | A directory to put the output files in                          |

### Built-in values

| Value name      | type     | Description                                       |
|-----------------|----------|---------------------------------------------------|
| `shareDir`      | `string` | Path to f4pga's installation "share" directory    |
| `python3`       | `string` | Path to Python 3 executable                       |
| `noisyWarnings` | `string` | Path to noisy warnings log (should be deprecated) |
| `prjxray_db`    | `string` | Path to Project X-Ray database                    |

### Used in flow definitions

| Value name    | type                               | Description                                                                                                                               |
|---------------|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `top`         | `string`                           | Top module name                                                                                                                           |
| `build_dir`   | `string`                           | Path to build directory (should be optional)                                                                                              |
| `device`      | `string`                           | Name of the device                                                                                                                        |
| `vpr_options` | `dict[string -> string \| number]` | Named options passed to VPR. No `--` prefix included.                                                                                     |
| `part_name`   | `string`                           | Name of the chip used. The distinction between `device` and `part_name` is ambiguous at the moment and should be addressed in the future. |
| `arch_def`    | `string`                           | Path to an XML file containing architecture definition.                                                                                   |
