cmake_minimum_required(VERSION 3.13)
project(symbiflow-docs)

include(doxygen.cmake)

add_doxygen_project(
	PRJNAME "prjxray"
	INPUT_DIR "${SYMBIFLOW_DOCS_DIR}/source/prjxray/lib"
              "${SYMBIFLOW_DOCS_DIR}/source/prjxray/tools"
	LANGUAGE "c++"
	FILE_EXTENSIONS ".cpp" ".cc" ".h" ".hh")
