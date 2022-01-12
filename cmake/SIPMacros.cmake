# Macros for SIP
# ~~~~~~~~~~~~~~
# Copyright (c) 2007, Simon Edwards <simon@simonzone.com>
# Redistribution and use is allowed according to the terms of the BSD license.
# For details see the accompanying COPYING-CMAKE-SCRIPTS file.
#
# SIP website: http://www.riverbankcomputing.co.uk/sip/index.php
#
# This file defines the following macros:
#
# ADD_SIP_PYTHON_MODULE (MODULE_NAME MODULE_SIP [library1, libaray2, ...])
#     Specifies a SIP file to be built into a Python module and installed.
#     MODULE_NAME is the name of Python module including any path name. (e.g.
#     os.sys, Foo.bar etc). MODULE_SIP the path and filename of the .sip file
#     to process and compile. libraryN are libraries that the Python module,
#     which is typically a shared library, should be linked to. The built
#     module will also be install into Python's site-packages directory.
#
# The behaviour of the ADD_SIP_PYTHON_MODULE macro can be controlled by a
# number of variables:
#
# SIP_INCLUDE_DIRS - List of directories which SIP will scan through when looking
#     for included .sip files. (Corresponds to the -I option for SIP.)
#
# SIP_TAGS - List of tags to define when running SIP. (Corresponds to the -t
#     option for SIP.)
#
# SIP_CONCAT_PARTS - An integer which defines the number of parts the C++ code
#     of each module should be split into. Defaults to 8. (Corresponds to the
#     -j option for SIP.)
#
# SIP_DISABLE_FEATURES - List of feature names which should be disabled
#     running SIP. (Corresponds to the -x option for SIP.)
#
# SIP_EXTRA_OPTIONS - Extra command line options which should be passed on to
#     SIP.

SET(SIP_INCLUDE_DIRS)
SET(SIP_TAGS)
SET(SIP_CONCAT_PARTS 8)
SET(SIP_DISABLE_FEATURES)
SET(SIP_EXTRA_OPTIONS)

find_file(sip_generate "sip-generate.py" PATHS ${CMAKE_MODULE_PATH})
find_file(pyproject_toml "pyproject.toml.in" PATHS ${CMAKE_MODULE_PATH})

MACRO(ADD_SIP_PYTHON_MODULE MODULE_NAME MODULE_SIP)
    GET_FILENAME_COMPONENT(module_name_toml ${MODULE_SIP} NAME_WE)

    SET(EXTRA_LINK_LIBRARIES ${ARGN})

    STRING(REPLACE "." "/" _x ${MODULE_NAME})
    GET_FILENAME_COMPONENT(_parent_module_path ${_x}  PATH)
    GET_FILENAME_COMPONENT(_child_module_name ${_x} NAME)

    GET_FILENAME_COMPONENT(_module_path ${MODULE_SIP} PATH)
    GET_FILENAME_COMPONENT(_abs_module_sip ${MODULE_SIP} ABSOLUTE)

    # We give this target a long logical target name.
    # (This is to avoid having the library name clash with any already
    # install library names. If that happens then cmake dependency
    # tracking get confused.)
    STRING(REPLACE "." "_" _logical_name ${MODULE_NAME})
    SET(_logical_name "python_module_${_logical_name}")

    FILE(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${_module_path})    # Output goes in this dir.

    SET(_sip_includes)
    FOREACH (_inc ${SIP_INCLUDES})
        GET_FILENAME_COMPONENT(_abs_inc ${_inc} ABSOLUTE)
        LIST(APPEND _sip_includes -I ${_abs_inc})
    ENDFOREACH (_inc )

    SET(_sip_tags)
    FOREACH (_tag ${SIP_TAGS})
        LIST(APPEND _sip_tags -t ${_tag})
    ENDFOREACH (_tag)

    SET(_sip_x)
    FOREACH (_x ${SIP_DISABLE_FEATURES})
        LIST(APPEND _sip_x -x ${_x})
    ENDFOREACH (_x ${SIP_DISABLE_FEATURES})

    set(CMAKE_CURRENT_SIP_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/_tmp")

    SET(_message "-DMESSAGE=Generating CPP code for module ${MODULE_NAME}")
    SET(_sip_output_files)
    FOREACH(CONCAT_NUM RANGE 0 ${SIP_CONCAT_PARTS} )
        IF( ${CONCAT_NUM} LESS ${SIP_CONCAT_PARTS} )
	    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/sip${_child_module_name}part${CONCAT_NUM}.cpp )
        ENDIF( ${CONCAT_NUM} LESS ${SIP_CONCAT_PARTS} )
    ENDFOREACH(CONCAT_NUM RANGE 0 ${SIP_CONCAT_PARTS} )
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/apiversions.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/array.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/bool.cpp)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/descriptors.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/int_convertors.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/objmap.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/qtlib.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/siplib.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/threads.c)
    SET(_sip_output_files ${_sip_output_files} ${CMAKE_CURRENT_SIP_OUTPUT_DIR}/${_child_module_name}/voidptr.c)

    # Suppress warnings
    IF(PEDANTIC)
      IF(MSVC)
        # 4996 deprecation warnings (bindings re-export deprecated methods)
        # 4701 potentially uninitialized variable used (sip generated code)
        # 4702 unreachable code (sip generated code)
        ADD_DEFINITIONS( /wd4996 /wd4701 /wd4702 )
      ELSE(MSVC)
        # disable all warnings
        ADD_DEFINITIONS( -w )
      ENDIF(MSVC)
    ENDIF(PEDANTIC)

    CONFIGURE_FILE(
        ${pyproject_toml}
	${CMAKE_CURRENT_BINARY_DIR}/pyproject.toml
    )

    ADD_CUSTOM_COMMAND(
        OUTPUT ${_sip_output_files}
        COMMAND ${CMAKE_COMMAND} -E echo ${message}
	COMMAND ${PYTHON_EXECUTABLE} ${sip_generate} --build-dir ${CMAKE_CURRENT_SIP_OUTPUT_DIR} --target-dir ${PYTHON_SITE_PACKAGES_INSTALL_DIR}/${_parent_module_path} --concatenate ${SIP_CONCAT_PARTS}
	COMMAND touch ${_sip_output_files}
	DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/pyproject.toml
    )
    ADD_LIBRARY(${_logical_name} MODULE ${_sip_output_files} ${SIP_EXTRA_SOURCE_FILES})
    IF (NOT APPLE)
        IF ("${Python3_VERSION_MINOR}" GREATER 7)
            MESSAGE(STATUS "Python > 3.7 - not linking to libpython")
        ELSE ()
            TARGET_LINK_LIBRARIES(${_logical_name} ${Python3_LIBRARIES})
        ENDIF ()
    ENDIF (NOT APPLE)
    TARGET_LINK_LIBRARIES(${_logical_name} ${EXTRA_LINK_LIBRARIES})
    IF (APPLE)
        SET_TARGET_PROPERTIES(${_logical_name} PROPERTIES LINK_FLAGS "-undefined dynamic_lookup")
    ENDIF (APPLE)
    SET_TARGET_PROPERTIES(${_logical_name} PROPERTIES PREFIX "" OUTPUT_NAME ${_child_module_name})

    IF (WIN32)
        SET_TARGET_PROPERTIES(${_logical_name} PROPERTIES SUFFIX ".pyd" IMPORT_PREFIX "_")
    ENDIF (WIN32)

    INSTALL(TARGETS ${_logical_name} DESTINATION "${Python3_SITEARCH}/${_parent_module_path}")

ENDMACRO(ADD_SIP_PYTHON_MODULE)
