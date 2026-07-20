execute_process(
    COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
    WORKING_DIRECTORY "${SRC_DIR}"
    OUTPUT_VARIABLE GIT_SHA_VALUE
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

execute_process(
    COMMAND "${GIT_EXECUTABLE}" diff --quiet --exit-code
    WORKING_DIRECTORY "${SRC_DIR}"
    RESULT_VARIABLE GIT_DIRTY_RESULT
    ERROR_QUIET
)

if(GIT_DIRTY_RESULT EQUAL 0)
    set(GIT_DIRTY "")
else()
    string(SUBSTRING "${GIT_SHA_VALUE}" 0 4 GIT_SHA_VALUE)
    set(GIT_DIRTY "drty")
endif()

if(NOT GIT_SHA_VALUE)
    set(GIT_SHA_VALUE "unknown")
endif()

set(CONTENT "#pragma once\n#define GIT_SHA \"${GIT_SHA_VALUE}${GIT_DIRTY}\"\n")

if(EXISTS "${OUT_FILE}")
    file(READ "${OUT_FILE}" OLD_CONTENT)
else()
    set(OLD_CONTENT "")
endif()

if(NOT OLD_CONTENT STREQUAL CONTENT)
    file(WRITE "${OUT_FILE}" "${CONTENT}")
endif()
