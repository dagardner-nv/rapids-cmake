#=============================================================================
# Copyright (c) 2021, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#=============================================================================
include_guard(GLOBAL)

#[=======================================================================[.rst:
rapids_find_package
-------------------

.. versionadded:: v21.06.00

Allow projects to find dependencies via `find_package` with built-in
tracking of these dependencies for correct export support.

.. code-block:: cmake

  rapids_find_package(<PackageName>
                      [REQUIRED]
                      [GLOBAL_TARGETS <targets...>]
                      [BUILD_EXPORT_SET <name>]
                      [INSTALL_EXPORT_SET <name>]
                      [ <FIND_ARGS>
                        all normal find_package options ]
                      )

Invokes :cmake:command:`find_package` call and associate this with the listed
build and install export set for correct export generation. Will propagate
all variables set by :cmake:command:`find_package` to the callers scope.

Since the visibility of CMake's targets differ between targets built locally and those
imported, :cmake:command:`rapids_find_package` promotes imported targets to be global
so users have consistency. List all targets used by your project in `GLOBAL_TARGET`.

.. note::
  If the project/package you are looking for doesn't have an existing
  CMake Find module, please look at using :cmake:command:`rapids_find_generate_module`.

``PackageName``
  Name of the package to find.

``GLOBAL_TARGETS``
  Which targets from this package should be made global. This information
  will be propagated to any associated export set.

``BUILD_EXPORT_SET``
  Record that a :cmake:command:`find_dependency(<PackageName>)` call needs to occur
  as part of our build directory export set.

``INSTALL_EXPORT_SET``
  Record that a :cmake:command:`find_dependency(<PackageName>)` call needs to occur
  as part of our build directory export set.

``FIND_ARGS``
  Required placeholder to be provied before any extra arguments that need to
  be passed down to cmake:command:`find_pacakge`


#]=======================================================================]
macro(rapids_find_package name)
  #
  # rapids_find_package breaks convention and is a macro on purpose. Since `find_package` allows
  # abitrary variable creation ( `<PROJECT_???>` ) we need to have `rapids_find_package` do the
  # same. If it doesn't it would make drop in replacements impossible
  #
  list(APPEND CMAKE_MESSAGE_CONTEXT "rapids.find.package")
  set(_rapids_options FIND_ARGS REQUIRED)
  set(_rapids_one_value BUILD_EXPORT_SET INSTALL_EXPORT_SET)
  set(_rapids_multi_value GLOBAL_TARGETS)
  cmake_parse_arguments(RAPIDS "${_rapids_options}" "${_rapids_one_value}" "${_rapids_multi_value}"
                        ${ARGN})

  set(_rapids_required_flag)
  if(RAPIDS_REQUIRED)
    set(_rapids_required_flag REQUIRED)
  endif()

  find_package(${name} ${_rapids_required_flag} ${RAPIDS_UNPARSED_ARGUMENTS})
  unset(_rapids_required_flag)

  if(RAPIDS_GLOBAL_TARGETS)
    include("${rapids-cmake-dir}/cmake/make_global.cmake")
    rapids_cmake_make_global(RAPIDS_GLOBAL_TARGETS)
  endif()

  # Only record the export requirements if the package was found This allows us to handle implicit
  # OPTIONAL find packages
  if(${${name}_FOUND})

    set(_rapids_extra_info)
    if(RAPIDS_GLOBAL_TARGETS)
      set(_rapids_extra_info "GLOBAL_TARGETS")
      list(APPEND _rapids_extra_info ${RAPIDS_GLOBAL_TARGETS})
    endif()

    if(RAPIDS_BUILD_EXPORT_SET)
      include("${rapids-cmake-dir}/export/package.cmake")
      rapids_export_package(BUILD ${name} ${RAPIDS_BUILD_EXPORT_SET} ${_rapids_extra_info})
    endif()

    if(RAPIDS_INSTALL_EXPORT_SET)
      include("${rapids-cmake-dir}/export/package.cmake")
      rapids_export_package(INSTALL ${name} ${RAPIDS_INSTALL_EXPORT_SET} ${_rapids_extra_info})
    endif()

    unset(_rapids_extra_info)
  endif()

  # Cleanup all our local variables
  foreach(_rapids_local_var IN LISTS _rapids_options _rapids_one_value _rapids_multi_value)
    if(DEFINED RAPIDS_${_rapids_local_var})
      unset(RAPIDS_${_rapids_local_var})
    endif()
  endforeach()
  unset(_rapids_local_var)
  unset(_rapids_options)
  unset(_rapids_one_value)
  unset(_rapids_multi_value)
  list(POP_BACK CMAKE_MESSAGE_CONTEXT)
endmacro()
