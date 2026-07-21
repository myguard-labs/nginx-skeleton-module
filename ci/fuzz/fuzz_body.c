/*
 * Copyright (C) 2026 Thijs Eilander
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * libFuzzer target for the seam/multi-chunk stream-scan logic
 * (ngx_http_skel_scan_piece), the piece of the module that carries a tail of
 * raw bytes across calls so a rule split at a chain-buffer/file-read boundary
 * is still caught. Links the SAME translation unit the live module calls
 * (src/ngx_http_skel_scan.c) with nginx's real ngx_string.c -- no stub, no
 * reimplementation.
 *
 * The property under test: chunking must never change the verdict. The input
 * is fed through scan_piece() in a single slice (fresh tail/tail_len=0) AND in
 * N slices with a carried tail threaded across the calls; the two verdicts
 * must agree. A mismatch means the seam carry either dropped a match that
 * spans a chunk boundary (an availability/detection bypass) or invented one
 * that isn't there (a false positive on the multi-chunk path only) -- exactly
 * the bug class this seam logic exists to prevent.
 *
 * The split schedule is derived FROM the input itself (leading length bytes),
 * not from any RNG, so a crashing input is deterministic and replayable.
 *
 * H2 (issues.md) is FIXED: the seam now decodes once and carries DECODED bytes
 * (plus any raw partial percent-escape held across the boundary), so chunking
 * no longer re-decodes an escape from the wrong state. This target runs in
 * discovery mode again. The end-of-stream flush (ngx_http_skel_stream_final) is
 * part of the verdict on BOTH the multi-slice and single-slice runs, so a rule
 * ending in a partial escape at the very end of the input is compared honestly.
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
    ngx_http_skel_stream_t  st_multi, st_single;
    size_t   sched_off, body_off, remaining, slice;
    ngx_int_t rc_multi, rc_single;

    if (size == 0) {
        return 0;
    }

    /*
     * Copy into an exact-sized heap allocation rather than casting the
     * libFuzzer buffer. ASan poisons the bytes immediately after a heap
     * block, so a one-past-the-end read in scan_piece faults here instead of
     * silently landing inside libFuzzer's own (larger) backing buffer.
     */
    buf = malloc(size);
    if (buf == NULL) {
        return 0;
    }
    memcpy(buf, data, size);

    /*
     * Derive a deterministic split schedule from the input's leading bytes:
     * each schedule byte is a slice length (mod 32, +1 so slices are never
     * zero-length and stay small enough to force multiple seams even on a
     * modest input). The schedule bytes themselves are still fed through
     * scan_piece() as body -- they are not consumed/hidden -- so the
     * multi-slice and single-slice runs see byte-for-byte identical input.
     */
    sched_off = 0;
    body_off = 0;
    remaining = size;
    memset(&st_multi, 0, sizeof(st_multi));
    rc_multi = NGX_HTTP_SKEL_CLEAN;

    while (remaining > 0 && rc_multi == NGX_HTTP_SKEL_CLEAN) {
        slice = (buf[sched_off % size] % 32) + 1;
        if (slice > remaining) {
            slice = remaining;
        }

        rc_multi = ngx_http_skel_scan_piece(&st_multi, buf + body_off, slice);

        body_off += slice;
        remaining -= slice;
        sched_off++;
    }

    if (rc_multi == NGX_HTTP_SKEL_CLEAN) {
        rc_multi = ngx_http_skel_stream_final(&st_multi);
    }

    /* Whole-input single slice, fresh state. */
    memset(&st_single, 0, sizeof(st_single));
    rc_single = ngx_http_skel_scan_piece(&st_single, buf, size);
    if (rc_single == NGX_HTTP_SKEL_CLEAN) {
        rc_single = ngx_http_skel_stream_final(&st_single);
    }

    if (rc_multi != rc_single) {
        /* Seam carry disagrees with the ground truth: a real bug, not a
         * fuzzer artifact. Abort so libFuzzer captures + minimizes the
         * input. */
        abort();
    }

    free(buf);

    return 0;
}
