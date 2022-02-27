# Installs sfbuild - experimental Symbiflow Build System

function(INSTALL_DIR)
  # Create directory during installation phase
  set(options)
  set(one_value_args INSTALL_DIRECTORY)
  set(multi_value_args)
  cmake_parse_arguments(
    INSTALL_DIR
    "${options}"
    "${one_value_args}"
    "${multi_value_args}"
    ${ARGN}
  )

  set(make_dir_code "file(MAKE_DIRECTORY ${INSTALL_DIR_INSTALL_DIRECTORY})")
  install(CODE ${make_dir_code})

endfunction()

function(INSTALL_DIR_CONTENT)
  # Install files from ROOT_DIRECTORY/FILES_DIRECTORY directory into a FILES_DIRECTORY subdirectory of INSTALL_DIRECTORY
  set(options)
  set(one_value_args
    ROOT_DIRECTORY
    FILES_DIRECTORY
    DESTINATION)
  set(multi_value_args
    FILES
    INSTALL_OPTS)
  cmake_parse_arguments(
    INSTALL_DIR_CONTENT
    "${options}"
    "${one_value_args}"
    "${multi_value_args}"
    ${ARGN}
  )

  if(NOT DEFINED INSTALL_DIR_CONTENT_ROOT_DIRECTORY)
    set(INSTALL_DIR_CONTENT_ROOT_DIRECTORY .)
  endif()
  if(NOT DEFINED INSTALL_DIR_CONTENT_FILES_DIRECTORY)
    set(INSTALL_DIR_CONTENT_FILES_DIRECTORY .)
  endif()

  set(file_paths)
  foreach(file ${INSTALL_DIR_CONTENT_FILES})
    list(APPEND file_paths ${INSTALL_DIR_CONTENT_ROOT_DIRECTORY}/${INSTALL_DIR_CONTENT_FILES_DIRECTORY}/${file})
  endforeach()

  install(FILES ${file_paths}
          DESTINATION ${INSTALL_DIR_CONTENT_DESTINATION}/${INSTALL_DIR_CONTENT_FILES_DIRECTORY}
          ${INSTALL_DIR_CONTENT_INSTALL_OPTS})
    
endfunction()


find_package(Python3 COMPONENTS Interpreter REQUIRED)

get_target_property_required(VPR env VPR)
get_target_property_required(GENFASM env GENFASM)

set(SFBUILD_SUPPORTED_PLATFORMS
  ql-eos-s3
  xc7a50t
  xc7a100t
  xc7a200t
  ql-k4n8_fast
  ql-k4n8_slow)

# Create required directories
foreach(DIR_PATH ${SFBUILD_DIRECTORIES})
  install_dir(INSTALL_DIRECTORY ${CMAKE_INSTALL_PREFIX}/bin/${DIR_PATH})
endforeach()

# Install sfbuild
install_dir_content(
  FILES
    __init__.py
    sf_argparse.py
    sf_cache.py
    sf_flow_config.py
    sf_module_inspector.py
    sf_stage.py
    sf_ugly.py
    sfbuild.py
    sfbuild
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_EXECUTE WORLD_READ OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
install_dir_content(
  FILES __init__.py
  FILES_DIRECTORY sf_common
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_EXECUTE WORLD_READ OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
install_dir_content(
  FILES __init__.py
  FILES_DIRECTORY sf_module
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_EXECUTE WORLD_READ OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
install_dir_content(
  FILES __init__.py
  FILES_DIRECTORY sf_module_runner
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_EXECUTE WORLD_READ OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
# Install common modules
install_dir_content(
  FILES
    fasm.py
    generic_script_wrapper.py
    io_rename.py
    mkdirs.py
    pack.py
    place_constraints.py
    place.py
    route.py
    synth.py
  FILES_DIRECTORY sf_common_modules
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_EXECUTE WORLD_READ OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
# Install platform flow definitions
set(sfbuild_supported_platform_defs)
foreach(SFBUILD_PLATFORM ${SFBUILD_SUPPORTED_PLATFORMS})
  set(sfbuild_platform_def "${SFBUILD_PLATFORM}.json")
  list(APPEND sfbuild_supported_platform_defs ${sfbuild_platform_def})
endforeach()
install_dir_content(
  FILES ${sfbuild_supported_platform_defs}
  FILES_DIRECTORY platforms
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_EXECUTE WORLD_READ OWNER_WRITE OWNER_READ GROUP_READ)

# Install part_db
install_dir_content(
  FILES
    parts.json
  FILES_DIRECTORY part_db
  DESTINATION bin/sfbuild
  INSTALL_OPTS
    PERMISSIONS WORLD_READ OWNER_WRITE OWNER_READ GROUP_READ
)
