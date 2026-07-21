add_library(corrosion_core STATIC)

target_sources(corrosion_core PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/core.c
)

target_include_directories(corrosion_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)