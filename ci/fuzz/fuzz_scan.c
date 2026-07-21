/*
 * Copyright (C) 2026 Thijs Eilander
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * libFuzzer target for the scan core.
 *
 * This drives ngx_http_skel_scan() -- the SAME translation unit the live module
 * calls -- with nginx's real ngx_unescape_uri() linked in from
 * src/core/ngx_string.c. There is no stub and no reimplementation, so a crash
 * here is a crash in production code.
 *
 * What it proves: no input of any length or byte content makes the normalize +
 * match path read out of bounds, overflow the fixed working buffer, or trip
 * UBSan. The verdict itself is not asserted (any verdict is legal for random
 * bytes) -- correctness of the verdict is the Test::Nginx suite's job.
 *
 * If the module grows a second parser (a header codec, a body format), give it
 * its own fuzz_<name>.c rather than multiplexing on the first input byte: a
 * shared corpus for two grammars starves both.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "ngx_http_skel_scan.h"


int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    u_char  *buf;

    if (size == 0) {
        return 0;
    }

    /*
     * Copy into an exact-sized heap allocation rather than casting the
     * libFuzzer buffer. ASan poisons the bytes immediately after a heap block,
     * so a one-past-the-end read in the scanner faults here instead of silently
     * landing inside libFuzzer's own (larger) backing buffer.
     */
    buf = malloc(size);
    if (buf == NULL) {
        return 0;
    }

    memcpy(buf, data, size);

    (void) ngx_http_skel_scan(buf, size);

    free(buf);

    return 0;
}
