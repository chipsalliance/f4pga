find_package(Doxygen REQUIRED)

### Global SymbiFlow variables

get_filename_component(SYMBIFLOW_DOCS_DIR "${PROJECT_SOURCE_DIR}/.." ABSOLUTE)
get_filename_component(SYMBIFLOW_DOCS_BUILD_DIR "${SYMBIFLOW_DOCS_DIR}/build" ABSOLUTE)
get_filename_component(SYMBIFLOW_DOCS_DOXYGEN_DIR "${SYMBIFLOW_DOCS_DIR}/doxygen" ABSOLUTE)
get_filename_component(SYMBIFLOW_DOCS_DOXYGEN_BUILD_DIR "${SYMBIFLOW_DOCS_BUILD_DIR}/doxygen" ABSOLUTE)


function(ADD_DOXYGEN_PROJECT)
  set(options)
  set(oneValueArgs PRJNAME LANGUAGE)
  set(multiValueArgs INPUT_DIR FILE_EXTENSIONS)
  cmake_parse_arguments(
    ADD_DOXYGEN_PROJECT
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN})

  ### Input validation

  if (("${ADD_DOXYGEN_PROJECT_PRJNAME}" STREQUAL "") OR
     ("${ADD_DOXYGEN_PROJECT_INPUT_DIR}" STREQUAL "") OR
     ("${ADD_DOXYGEN_PROJECT_LANGUAGE}" STREQUAL ""))
    message(FATAL_ERROR
           "Missing function argument!\n"
           "ADD_DOXYGEN_PROJECT(\n"
           "  PRJNAME <name>\n"
           "  INPUT_DIR <input_dir_1> {<input_dir_n>}\n"
           "  LANGUAGE <language>)")
  endif()

  if ((NOT "${ADD_DOXYGEN_PROJECT_LANGUAGE}" STREQUAL "c++") AND
     (NOT "${ADD_DOXYGEN_PROJECT_LANGUAGE}" STREQUAL "c"))
    message(FATAL_ERROR
           "Language: ${ADD_DOXYGEN_PROJECT_LANGUAGE} is not supported!")
  endif()

  ### Project settings

  set(PROJECT_OUTPUT_FILE "${SYMBIFLOW_DOCS_DOXYGEN_BUILD_DIR}/${ADD_DOXYGEN_PROJECT_PRJNAME}/xml/index.xml")
  set(PROJECT_DOXYFILE "${SYMBIFLOW_DOCS_DOXYGEN_DIR}/build/${ADD_DOXYGEN_PROJECT_PRJNAME}.doxyfile")
  if (("${ADD_DOXYGEN_PROJECT_LANGUAGE}" STREQUAL "c") OR
     ("${ADD_DOXYGEN_PROJECT_LANGUAGE}" STREQUAL "c++"))
    set(PROJECT_DOXYFILE_IN "${SYMBIFLOW_DOCS_DOXYGEN_DIR}/c.doxyfile.in")
  endif()

  ### Searching for all files in the project

  foreach(ext ${ADD_DOXYGEN_PROJECT_FILE_EXTENSIONS})
    foreach(input ${ADD_DOXYGEN_PROJECT_INPUT_DIR})
      list(APPEND GLOBBING_DIRS "${input}/*${ext}")
    endforeach()
  endforeach()

  file(GLOB_RECURSE PROJECT_FILES CONFIGURE_DEPENDS ${GLOBBING_DIRS})

  ### Doxygen settings

  set(DOXYGEN_PROJECT_NAME "${ADD_DOXYGEN_PROJECT_PRJNAME}")
  set(DOXYGEN_OUTPUT_DIRECTORY "${SYMBIFLOW_DOCS_DOXYGEN_BUILD_DIR}/${ADD_DOXYGEN_PROJECT_PRJNAME}")
  string(REPLACE ";" " \\\n" DOXYGEN_INPUT "${ADD_DOXYGEN_PROJECT_INPUT_DIR}")
  foreach(ext ${ADD_DOXYGEN_PROJECT_FILE_EXTENSIONS})
      list(APPEND DOXYGEN_FILE_PATTERNS "*${ext}")
  endforeach()
  string(REPLACE ";" " " DOXYGEN_FILE_PATTERNS "${DOXYGEN_FILE_PATTERNS}")

  # Fill in the Doxyfile with the project's values
  configure_file("${PROJECT_DOXYFILE_IN}" "${PROJECT_DOXYFILE}" @ONLY)

  ### Prerequisites

  # Ensure that docs will be correctly regenerated
  file(REMOVE "${PROJECT_OUTPUT_FILE}")

  # Ensure that needed directories are created
  file(MAKE_DIRECTORY "${DOXYGEN_OUTPUT_DIRECTORY}")

  ### Create Makefile targets

  add_custom_command(OUTPUT  "${PROJECT_OUTPUT_FILE}"
                     DEPENDS "${PROJECT_FILES}"
                     COMMAND "${DOXYGEN_EXECUTABLE}" "${PROJECT_DOXYFILE}"
                     WORKING_DIRECTORY "${SYMBIFLOW_DOCS_DOXYGEN_DIR}"
                     MAIN_DEPENDENCY "${PROJECT_DOXYFILE}"
                     COMMENT "Generating doxygen docs for ${ADD_DOXYGEN_PROJECT_PRJNAME}...")

  add_custom_target("docs-${ADD_DOXYGEN_PROJECT_PRJNAME}"
                    ALL
                    DEPENDS "${PROJECT_OUTPUT_FILE}" "${PROJECT_FILES}")
endfunction()
