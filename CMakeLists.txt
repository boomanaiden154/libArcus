project(Arcus)
cmake_minimum_required(VERSION 3.13)

# Basic projects options
option(BUILD_PYTHON "Build Python module" ON)
option(BUILD_EXAMPLES "Build the example programs" ON)
option(BUILD_STATIC "Build as a static library" OFF)

include(cmake/StandardProjectSettings.cmake)

set(arcus_SRCS
        src/Socket.cpp
        src/SocketListener.cpp
        src/MessageTypeStore.cpp
        src/PlatformSocket.cpp
        src/Error.cpp)

set(arcus_HDRS_PRIVATE
        src/Socket_p.h
        src/PlatformSocket_p.h
        src/WireMessage_p.h
        )

set(arcus_HDRS
        include/Arcus/Socket.h
        include/Arcus/SocketListener.h
        include/Arcus/Types.h
        include/Arcus/MessageTypeStore.h
        include/Arcus/Error.h
        )

if(${BUILD_SHARED_LIBS})
    add_library(Arcus SHARED ${arcus_SRCS})
else()
    add_library(Arcus STATIC ${arcus_SRCS})
endif()

use_threads(Arcus)

find_package(Protobuf 3.17.1 REQUIRED)
target_link_libraries(Arcus PRIVATE protobuf::libprotobuf)

set_project_standards(Arcus)
set_project_warnings(Arcus)
enable_sanitizers(Arcus)

if(NOT MSVC)
    if(${CMAKE_BUILD_TYPE} STREQUAL "Debug" OR ${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo")
        target_compile_definitions(Arcus PUBLIC -DARCUS_DEBUG)
    endif()
endif()

if(WIN32)
    # Declare we require Vista or higher, this allows us to use IPv6 functions.
    target_compile_definitions(Arcus PUBLIC -D_WIN32_WINNT=0x0600)
    target_link_libraries(Arcus PUBLIC Ws2_32)
endif()

target_include_directories(Arcus
        PUBLIC
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        PRIVATE
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        )

if(${CMAKE_BUILD_TYPE})
    if(${CMAKE_BUILD_TYPE} STREQUAL "Debug" OR ${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo")
        add_definitions(-DARCUS_DEBUG)
    endif()
endif()

if(BUILD_PYTHON)
    list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

    find_package(sip REQUIRED)
    if(NOT DEFINED LIB_SUFFIX)
        set(LIB_SUFFIX "")
    endif()

    set(SIP_EXTRA_FILES_DEPEND python/SocketListener.sip python/Types.sip python/PythonMessage.sip python/Error.sip)
    set(SIP_EXTRA_SOURCE_FILES python/PythonMessage.cpp)
    set(SIP_EXTRA_OPTIONS -y Arcus.pyi -o -g -n PyQt5.sip) # -g means always release the GIL before calling C++ methods. -n PyQt5.sip is required to not get the PyCapsule error
    add_sip_python_module(Arcus python/Socket.sip Arcus)
    use_python(python_module_Arcus Interpreter Development)

    target_link_libraries(python_module_Arcus
            PRIVATE
                sip::sip
                protobuf::libprotobuf
                Arcus
            )
    target_include_directories(python_module_Arcus
            PRIVATE
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/python>
            )
    set_project_standards(python_module_Arcus)
    set_project_warnings(python_module_Arcus)
endif()

if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

install(TARGETS Arcus
        EXPORT Arcus-targets
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/Arcus
        )
