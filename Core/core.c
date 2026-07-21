#include "core.h"

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

__attribute__((section(".META_DATA"), used, aligned(4)))
const uint32_t metadata = UINT32_C(0xDEADBEEF);

const uint32_t * metadata_reference(void)
{
    return &metadata;
}

int core_run(void)
{
    const uint32_t * meta_ref = metadata_reference();


    return 0;
}