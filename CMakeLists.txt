cmake_minimum_required(VERSION 3.22)
project(CORROSION_ANALYZER LANGUAGES C VERSION 2.0.0.10)

find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Git REQUIRED QUIET)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

message(STATUS "Selected platform: ${PLATFORM}")

set(GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
set(GIT_SHA_HEADER "${GENERATED_DIR}/git_sha.h")

file(MAKE_DIRECTORY "${GENERATED_DIR}")

add_custom_target(git_sha_header ALL
    COMMAND ${CMAKE_COMMAND}
        -DGIT_EXECUTABLE=${GIT_EXECUTABLE}
        -DSRC_DIR=${CMAKE_SOURCE_DIR}
        -DOUT_FILE=${GIT_SHA_HEADER}
        -P ${CMAKE_SOURCE_DIR}/cmake/gen_git_sha.cmake
    COMMENT "Generating git_sha.h"
    VERBATIM
)

include_directories("${GENERATED_DIR}")

if(PLATFORM STREQUAL "RA6T2")

    include(ExternalProject)

    ExternalProject_Add(ra6t2_firmware
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/Platform/RA6T2
        BINARY_DIR ${CMAKE_BINARY_DIR}/ra6t2_build
        CMAKE_ARGS
            -DAPP_ROOT:PATH=${CMAKE_SOURCE_DIR}
            -DPLATFORM=RA6T2
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_SOURCE_DIR}/cmake/arm-none-eabi.cmake
            -DARM_GNU_TOOLCHAIN_BIN:PATH=${ARM_GNU_TOOLCHAIN_BIN}
            -DRASC_EXE_PATH=${RASC_EXE_PATH}
            -DGIT_SHA_HEADER_DIR:PATH=${GENERATED_DIR}
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
        INSTALL_COMMAND ""
        BUILD_ALWAYS 1 #Workaround to force compile always
    )

    add_dependencies(ra6t2_firmware git_sha_header)

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(CRC_BUILD_ARG "D")
    else()
        set(CRC_BUILD_ARG "R")
    endif()

else()
    message(FATAL_ERROR "Unknown PLATFORM: ${PLATFORM}")
endif()
