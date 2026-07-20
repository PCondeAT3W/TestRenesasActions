set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(ARM_GNU_TOOLCHAIN_BIN "" CACHE PATH "ARM GNU toolchain bin path")

set(CMAKE_C_COMPILER   "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-gcc.exe")
set(CMAKE_CXX_COMPILER "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-g++.exe")
set(CMAKE_ASM_COMPILER "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-gcc.exe")

set(CMAKE_AR     "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-ar.exe")
set(CMAKE_RANLIB "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-ranlib.exe")
set(CMAKE_NM     "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-nm.exe")

set(CMAKE_OBJCOPY "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-objcopy.exe")
set(CMAKE_SIZE    "${ARM_GNU_TOOLCHAIN_BIN}/arm-none-eabi-size.exe")

# Evitar que CMake encuentre librerías/headers del host por accidente
set(CMAKE_FIND_ROOT_PATH "${ARM_GNU_TOOLCHAIN_BIN}/..")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
