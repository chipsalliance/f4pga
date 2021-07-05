# sfbuild module "io_rename"

##### _Category: Common_

-------------------------------

This module provides a way to rename (ie. change) dependencies and values of an
instance of a different module. It wraps another, module whoose name is specified in `params.module` and changes the names of the dependencies and values it relies on.

## Setup

### 1. Parameters 

* `module` (string, required) - name of the wrapped module
* `params` (dict[string -> any], optional): parameters passed to the wrapped
  module instance.
* `rename_takes` (dict[string -> string]) - mapping for inputs ("takes")
* `rename_produces` (dict[string -> string]) - mapping for outputs ("products")
* `rename_values` (dict[string -> string]) - mapping for values

In the three mapping dicts, keys represent the names visible to the wrapped module
and values represent the names visible to the modules outside.
Not specifying a mapping for a given entry will leave it with its original name.

### 2. Values

All values specified for this modules will be accessible by tyhe wrapped module.