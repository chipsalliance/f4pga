# Adding C++ support for a new project

1. Add the project to the `symbiflow-docs/doxygen/CMakeLists.txt`, i.e:

```
add_doxygen_project(
    PRJNAME "prjxray"
    INPUT_DIR "${SYMBIFLOW_DOCS_DIR}/source/prjxray/lib"
              "${SYMBIFLOW_DOCS_DIR}/source/prjxray/tools"
    LANGUAGE "c++"
    FILE_EXTENSIONS ".cpp" ".cc" ".h" ".hh")
```

- `PRJNAME` - the project's name
- `INPUT_DIR` - input directories which will be recursively scanned for
    documented files
- `LANGUAGE` - the programming language of the project (currently only "c" and "c++" are supported")
  This variable is used to determine proper doxygen configuration template (`<lang>.doxyfile.in` file)
- `FILE_EXTENSIONS` - extensions of the files that contain documentation

The generated doxygen documentation will be placed in
`symbiflow-docs/build/doxygen/<PRJNAME>/xml` directory

2. Add the project to the `breathe_projects` variable in `symbiflow-docs/source/conf.py`:

```
breathe_projects = {
    ...
    "prjxray" : "../build/doxygen/prjxray/xml",
    ...
}
```

The first field in the dictionary refers to the project's name.
This value is placed after `:project:` property in the Breathe's directives.

The second field in dictionary refers to the Doxygen documentation output directory.
It should be a relative path to generated Doxygen documentation, mentioned above.

3. Now you can document the project using the breathe plugin.
Note that every class should be documented using its full namespace, i.e:

```
.. doxygenclass:: prjxray::xilinx::xc7series::ConfigurationBus
   :project: prjxray
```

