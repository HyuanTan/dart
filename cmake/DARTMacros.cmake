#===============================================================================
# Appends items to a cached list.
# Usage:
#   dart_append_to_cached_string(_string _cacheDesc [items...])
#===============================================================================
macro(dart_append_to_cached_string _string _cacheDesc)
  foreach(newItem ${ARGN})
    set(${_string} "${${_string}}${newItem}" CACHE INTERNAL ${_cacheDesc} FORCE)
  endforeach()
endmacro()

#===============================================================================
# Get list of file names give list of full paths.
# Usage:
#   dart_get_filename_components(_var _cacheDesc [items...])
#===============================================================================
macro(dart_get_filename_components _var _cacheDesc)
  set(${_var} "" CACHE INTERNAL ${_cacheDesc} FORCE)
  foreach(header ${ARGN})
    get_filename_component(header ${header} NAME)
    dart_append_to_cached_string(
      ${_var}
      ${_cacheDesc}"_HEADER_NAMES"
      "${header}\;"
    )
  endforeach()
endmacro()

#===============================================================================
# Generate directory list of ${curdir}
# Usage:
#   dart_get_subdir_list(var curdir)
#===============================================================================
macro(dart_get_subdir_list var curdir)
    file(GLOB children RELATIVE ${curdir} "${curdir}/*")
    set(dirlist "")
    foreach(child ${children})
        if(IS_DIRECTORY ${curdir}/${child})
            LIST(APPEND dirlist ${child})
        endif()
    endforeach()
    set(${var} ${dirlist})
endmacro()

#===============================================================================
# Generate header file list to a cached list.
# Usage:
#   dart_generate_include_header_list(_var _target_dir _cacheDesc [headers...])
#===============================================================================
macro(dart_generate_include_header_list _var _target_dir _cacheDesc)
  set(${_var} "" CACHE INTERNAL ${_cacheDesc} FORCE)
  foreach(header ${ARGN})
    dart_append_to_cached_string(
      ${_var}
      ${_cacheDesc}"_HEADERS"
      "#include \"${_target_dir}${header}\"\n"
    )
  endforeach()
endmacro()

#===============================================================================
# Add library and set target properties
# Usage:
#   dart_add_library(_libname source1 [source2 ...])
#===============================================================================
macro(dart_add_library _name)
  add_library(${_name} ${ARGN})
  set_target_properties(
    ${_name} PROPERTIES
    SOVERSION "${DART_MAJOR_VERSION}.${DART_MINOR_VERSION}"
    VERSION "${DART_VERSION}"
  )
endmacro()

#===============================================================================
function(dart_property_add property_name)

  get_property(is_defined GLOBAL PROPERTY ${property_name} DEFINED)

  if(NOT is_defined)
    define_property(GLOBAL PROPERTY ${property_name}
      BRIEF_DOCS "${property_name}"
      FULL_DOCS "Global properties for ${property_name}"
    )
  endif()

  foreach(item ${ARGN})
    set_property(GLOBAL APPEND PROPERTY ${property_name} "${item}")
  endforeach()

endfunction()

#===============================================================================
function(dart_check_required_package variable dependency)
  if(${${variable}_FOUND})
    if(DART_VERBOSE)
      message(STATUS "Looking for ${dependency} - version ${${variable}_VERSION}"
                     " found")
    endif()
  endif()
endfunction()

#===============================================================================
macro(dart_check_optional_package variable component dependency)
  if(${${variable}_FOUND})
    set(HAVE_${variable} TRUE CACHE BOOL "Check if ${variable} found." FORCE)
    if(DART_VERBOSE)
      message(STATUS "Looking for ${dependency} - version ${${variable}_VERSION}"
                     " found")
    endif()
  else()
    set(HAVE_${variable} FALSE CACHE BOOL "Check if ${variable} found." FORCE)
    if(ARGV3) # version
      message(STATUS "Looking for ${dependency} - NOT found, to use"
                     " ${component}, please install ${dependency} (>= ${ARGV3})")
    else()
      message(STATUS "Looking for ${dependency} - NOT found, to use"
                     " ${component}, please install ${dependency}")
    endif()
    return()
  endif()
endmacro()

#===============================================================================
function(dart_add_custom_target rel_dir property_name)
  set(abs_dir "${CMAKE_CURRENT_LIST_DIR}/${rel_dir}")

  if(NOT IS_DIRECTORY ${abs_dir})
    message(SEND_ERROR "Failed to find directory: ${abs_dir}")
  endif()

  # Use the directory name as the executable name
  get_filename_component(target_name ${rel_dir} NAME)

  file(GLOB hdrs "${abs_dir}/*.hpp")
  file(GLOB srcs "${abs_dir}/*.cpp")
  if(srcs)
    add_executable(${target_name} EXCLUDE_FROM_ALL ${hdrs} ${srcs})
    target_link_libraries(${target_name} ${ARGN})
    dart_property_add(${property_name} ${target_name})
  endif()
endfunction()

#===============================================================================
function(dart_add_example)
  dart_property_add(DART_EXAMPLES ${ARGN})
endfunction(dart_add_example)

#===============================================================================
function(dart_add_tutorial)
  dart_property_add(DART_TUTORIALS ${ARGN})
endfunction(dart_add_tutorial)

#===============================================================================
function(dart_format_add)
  foreach(source ${ARGN})
    if(IS_ABSOLUTE "${source}")
      set(source_abs "${source}")
    else()
      get_filename_component(source_abs
        "${CMAKE_CURRENT_LIST_DIR}/${source}" ABSOLUTE)
    endif()
    if(EXISTS "${source_abs}")
      dart_property_add(DART_FORMAT_FILES "${source_abs}")
    else()
      message(FATAL_ERROR
        "Source file '${source}' does not exist at absolute path"
        " '${source_abs}'. This should never happen. Did you recently delete"
        " this file or modify 'CMAKE_CURRENT_LIST_DIR'")
    endif()
  endforeach()
endfunction()

#===============================================================================
# Macro to check for visibility capability in compiler
macro(check_compiler_visibility variable)
  include(CheckCXXCompilerFlag)
  check_cxx_compiler_flag(-fvisibility=hidden ${variable})
endmacro()

#===============================================================================
# Function to create an export header for control of binary symbols visibility.
#
# dart_add_export_file(<target_name>
#     [BASE_NAME <base_name>]
#     [COMPONENT_PATH <component_path>]
function(dart_add_export_file target_name)
  # Parse boolean, unary, and list arguments from input.
  # Unparsed arguments can be found in variable ARG_UNPARSED_ARGUMENTS.
  set(prefix _geh)
  set(options "")
  set(oneValueArgs BASE_NAME COMPONENT_PATH)
  set(multiValueArgs "")
  cmake_parse_arguments(
    "${prefix}" "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
  )

  include(GNUInstallDirs)

  # Base name
  set(base_name "${target_name}")
  string(REPLACE "-" "_" base_name ${base_name})
  if(_geh_BASE_NAME)
    set(base_name ${_geh_BASE_NAME})
  endif()
  string(TOUPPER ${base_name} base_name_upper)
  string(TOLOWER ${base_name} base_name_lower)

  # Componenet path
  set(component_path "dart")
  if(_geh_COMPONENT_PATH)
    set(component_path "dart/${_geh_COMPONENT_PATH}")
  endif()
  set(component_detail_export_path "${component_path}/detail/export.h")

  # Generate CMake's default export header
  include(GenerateExportHeader)
  generate_export_header(${target_name}
    EXPORT_MACRO_NAME ${base_name_upper}_DETAIL_API
    EXPORT_FILE_NAME detail/export.h
    DEPRECATED_MACRO_NAME ${base_name_upper}_DETAIL_DEPRECATED
  )
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/detail/export.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/dart/detail
    COMPONENT headers
  )

  # Generate final export header
  set(header_guard_name ${base_name_upper}_EXPORT_HPP_)
  set(output_path "${CMAKE_CURRENT_BINARY_DIR}/export.hpp")
  file(WRITE "${output_path}" "")
  file(APPEND "${output_path}" "// Automatically generated file by CMake\n")
  file(APPEND "${output_path}" "\n")
  file(APPEND "${output_path}" "#ifndef ${header_guard_name}\n")
  file(APPEND "${output_path}" "#define ${header_guard_name}\n")
  file(APPEND "${output_path}" "\n")
  file(APPEND "${output_path}" "#include \"${component_detail_export_path}\"\n")
  file(APPEND "${output_path}" "\n")
  file(APPEND "${output_path}" "#define ${base_name_upper}_API\\\n")
  file(APPEND "${output_path}" "    ${base_name_upper}_DETAIL_API\n")
  file(APPEND "${output_path}" "\n")
  file(APPEND "${output_path}" "#define ${base_name_upper}_DEPRECATED_API(version)\\\n")
  file(APPEND "${output_path}" "    ${base_name_upper}_DETAIL_DEPRECATED_EXPORT\n")
  file(APPEND "${output_path}" "\n")
  file(APPEND "${output_path}" "#endif // ${header_guard_name}\n")
  install(
    FILES ${output_path}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/component_path
    COMPONENT headers
  )
endfunction()
