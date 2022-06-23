# yosys

The _yosys_ module executes Yosys with an f4pga-compatible Tcl script.

The module guarantees the following outputs:
 * `yosys_${stage]_log` (on demand)
 * _tcl-defined I/O_*

*f4pga-compatible Yosys Tcl scripts declare their dependencies vand values.

## f4pga-compatible Yosys Tcl

Tcl scripts provided to yosys by f4gpa can interface with f4pga thorugh `f4pga` command.
This command is used to declare _takes_, _products_, _values_ and to manage temporary files
used by Tcl scripts.

### Declare a _take_ dependency:
```
f4pga take depName
```
This will create `f4pga_depName` variable that should contain path to the dependency `depName`.
`?` qualifier is supported - if dependency is not present, the `f4pga_depName` will be empty.

### Declare a _produce_ dependency:

```
f4pga produce depName defaultPath ?-meta description?
```
This will create `f4pga_depName` variable that should contain path to the dependency `depName`.
`defaultPath` will be used for generating default mapping for the path of `depName`.
The optional `-meta decription` argument binds `description` as metadata of `depName`.
`!` qualifier is not supported at the moment.

### Declare a _value_

```
f4pga value valueName
```

This will create `f4pga_valueName` variable that should contain the value of `valueName`.
`?` qualifier is supported - if value is not present, the `f4pga_valueName` will be empty.

### Use a temporary file

```
f4pga tempfile binding
```

A unique path will be generated and stored in `f4pga_binding` variable.
After the script executes, if a file is present under that path, it will get removed.

Note: This by itself won't create any files.

## Parameters

* `tcl_script` (string, required): A path to an f4pga-compatible Tcl script to use with
  Yosys.

## Values

The `synth` module requires the following values:

* `yosys_plugins` (list[string], optional): List of yosys plugins to preload
* _tcl-defined I/O_*
