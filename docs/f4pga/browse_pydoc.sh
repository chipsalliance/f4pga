#!/bin/sh

MY_DIR=`dirname $0`
SFBUILD_DIR=${MY_DIR}/../../f4pga
SFBUILD_PY=${SFBUILD_DIR}/__init__.py

PYTHONPATH=${SFBUILD_DIR} pydoc -b
