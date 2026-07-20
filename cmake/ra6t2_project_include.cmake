if(DEFINED _AT3W_RA6T2_PROJECT_INCLUDE_DONE)
  return()
endif()
set(_AT3W_RA6T2_PROJECT_INCLUDE_DONE TRUE)

if(NOT DEFINED APP_ROOT)
  message(FATAL_ERROR "[AT3W] APP_ROOT not defined. Pass -DAPP_ROOT=<repo_root> when configuring RA6T2 ExternalProject.")
endif()

if(NOT DEFINED PLATFORM)
  message(FATAL_ERROR "[AT3W] PLATFORM not defined. Set PLATFORM = RA6T2 from the CMakePresets.json .")
endif()

if(NOT DEFINED RASC_CMAKE_C_FLAGS)
  message(FATAL_ERROR "[AT3W] RASC_CMAKE_C_FLAGS not defined. Ensure FSP GeneratedCfg.cmake ran before this include.")
endif()

# Renesas flags propagation (so libraries are compiled with the corresponding flags)
add_library(ra6t2_fsp_flags INTERFACE)
target_compile_options(ra6t2_fsp_flags INTERFACE ${RASC_CMAKE_C_FLAGS})
if(DEFINED RASC_CMAKE_DEFINITIONS)
  target_compile_definitions(ra6t2_fsp_flags INTERFACE ${RASC_CMAKE_DEFINITIONS})
endif()
target_compile_definitions(ra6t2_fsp_flags INTERFACE
  $<$<CONFIG:Release>:NDEBUG>
)

# Core RA/FSP include dirs
set(_RA_INCS
  "${CMAKE_SOURCE_DIR}"
  "${CMAKE_SOURCE_DIR}/src"
  "${CMAKE_SOURCE_DIR}/ra"
  "${CMAKE_SOURCE_DIR}/ra/arm/CMSIS_6/CMSIS/Core/Include"
  "${CMAKE_SOURCE_DIR}/ra/fsp/inc"
  "${CMAKE_SOURCE_DIR}/ra/fsp/inc/api"
  "${CMAKE_SOURCE_DIR}/ra/fsp/inc/instances"
  "${CMAKE_SOURCE_DIR}/ra_cfg"
  "${CMAKE_SOURCE_DIR}/ra_cfg/fsp_cfg"
  "${CMAKE_SOURCE_DIR}/ra_cfg/fsp_cfg/bsp"
  "${CMAKE_SOURCE_DIR}/ra_gen"
)

add_subdirectory("${APP_ROOT}/Core"                                               "${CMAKE_BINARY_DIR}/_at3w_core")

if(TARGET corrosion_core)
  target_compile_definitions(corrosion_core PUBLIC 
  PLATFORM_RA6T2
  $<$<CONFIG:Debug>:_DEBUG_>
  $<$<CONFIG:Release>:_RELEASE_>
  )
  target_link_libraries(corrosion_core PRIVATE ra6t2_fsp_flags)
  target_include_directories(corrosion_core PRIVATE "${GIT_SHA_HEADER_DIR}")
  target_include_directories(corrosion_core PRIVATE  ${_RA_INCS})
  target_include_directories(corrosion_core PRIVATE 
    "${CMAKE_SOURCE_DIR}/ra/aws/FreeRTOS/FreeRTOS/Source/include"
    "${CMAKE_SOURCE_DIR}/ra_cfg/aws"
    "${CMAKE_SOURCE_DIR}/ra/fsp/src/rm_freertos_port"
    )
endif()

add_library(platform_ra6t2 STATIC)

target_sources(platform_ra6t2 PRIVATE
  "${CMAKE_SOURCE_DIR}/src/ra6t2.c"
)

# Includes para que encuentre hal_data.h y headers FSP/BSP
foreach(d IN LISTS _RA_INCS)
  if(EXISTS "${d}")
    target_include_directories(platform_ra6t2 PRIVATE "${d}")
  endif()
endforeach()

target_include_directories(platform_ra6t2 PRIVATE 
  ${APP_ROOT}/Middleware/SEGGER_RTT/inc
  "${CMAKE_SOURCE_DIR}/ra/aws/FreeRTOS/FreeRTOS/Source/include"
  "${CMAKE_SOURCE_DIR}/ra_cfg/aws"
  "${CMAKE_SOURCE_DIR}/ra/fsp/src/rm_freertos_port"
  )

# CPU/ABI flags correctos para esta librería
target_link_libraries(platform_ra6t2 PRIVATE 
  ra6t2_fsp_flags 
  corrosion_core 
  segger
  )

function(_at3w_link_into_ra6t2_elf)

  if(NOT TARGET RA6T2.elf)
    get_property(_t DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
    message(FATAL_ERROR "[AT3W] Target RA6T2.elf not found. Available targets: ${_t}")
  endif()

  target_link_libraries(RA6T2.elf PRIVATE
    platform_ra6t2
    corrosion_core
  )
  target_compile_definitions(RA6T2.elf PRIVATE
    $<$<CONFIG:Release>:NDEBUG>
  )

  message(STATUS "[AT3W] Linked app + middleware into RA6T2.elf")
endfunction()

cmake_language(DEFER CALL _at3w_link_into_ra6t2_elf)
