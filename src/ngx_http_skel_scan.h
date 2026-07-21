/*
 * Copyright (C) 2026 Thijs Eilander
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * The scan core: the module's decision logic, isolated from nginx's request
 * machinery.
 *
 * Everything here takes plain (u_char *, size_t) buffers. That is deliberate,
 * and it is what makes the CI harness honest: ci/fuzz/fuzz_scan.c links THIS
 * translation unit, so the fuzzer drives the same bytes through the same code
 * that serves live traffic -- not a reimplementation that can drift from it.
 *
 * The rule when extending a module from this skeleton: parsing and matching go
 * here; only the ngx_http_request_t plumbing stays in the module .c.
 */

#ifndef _NGX_HTTP_SKEL_SCAN_H_INCLUDED_
#define _NGX_HTTP_SKEL_SCAN_H_INCLUDED_


#include <ngx_config.h>
#include <ngx_core.h>


#define NGX_HTTP_SKEL_MODE_OFF     0
#define NGX_HTTP_SKEL_MODE_DETECT  1
#define NGX_HTTP_SKEL_MODE_BLOCK   2

/* Scan verdicts. CLEAN is 0 so `if (rc)` reads as "matched". */
#define NGX_HTTP_SKEL_CLEAN        0
#define NGX_HTTP_SKEL_MATCH        1

/*
 * Cap on the working buffer the normalizer decodes into. A buffer longer than
 * this is scanned only up to the cap: percent-decoding never expands, so the
 * cap bounds both the input consumed and the stack the scan uses, and no
 * attacker-supplied length can size an allocation.
 *
 * This is a HARD, stack-bounded window, not a policy knob: ngx_http_skel_scan
 * silently truncates past it (by design -- see the function's own comment)
 * and never allocates or logs to stay linkable straight into the fuzz target
 * (ci/fuzz/ngx_stubs.c aborts if it ever does). A caller that needs to cover
 * more than NGX_HTTP_SKEL_SCAN_MAX bytes of a single logical field MUST
 * pre-chunk with overlap itself -- see ngx_http_skel_scan_body() in the
 * module .c for the carried-tail pattern this implies, and
 * ngx_http_skel_log_if_truncated() for how the module makes truncation
 * observable at the call site (this header/TU deliberately does not).
 */
#define NGX_HTTP_SKEL_SCAN_MAX     8192

/*
 * Longest rule pattern the table can hold, in DECODED bytes. Used by callers
 * that scan a stream in pieces (see ngx_http_skel_scan_body in the module .c)
 * to size the carry-over tail that catches a rule split across two buffers.
 *
 * The streaming seam (ngx_http_skel_scan_piece) now decodes ONCE and carries
 * DECODED bytes across the boundary (not raw bytes -- see issues.md H2, where a
 * raw carry re-decoded a percent-escape from the wrong state). So the carry is
 * a decoded-length window: a decoded rule of D bytes needs D-1 bytes on each
 * side of the seam to be caught when split. No 3x raw expansion factor applies.
 *
 * LOAD-BEARING INVARIANT: a decoded rule must be <= NGX_HTTP_SKEL_MAX_RULE_LEN
 * - 1 to be caught when split across a buffer seam. Checked at config load by
 * ngx_http_skel_scan_rules_valid() below. If you add a longer rule in a derived
 * module, raise this constant or config load fails.
 */
#define NGX_HTTP_SKEL_MAX_RULE_LEN 64

/*
 * Bytes of raw input the streaming scan holds back across a piece boundary when
 * the piece ends mid percent-escape ("...%" or "...%A"). At most 2: a complete
 * escape is 3 raw bytes and always decodes in isolation. See
 * ngx_http_skel_scan_piece().
 */
#define NGX_HTTP_SKEL_HOLD_MAX     2


/*
 * Scan `len` bytes at `data`.
 *
 * Returns NGX_HTTP_SKEL_MATCH if the buffer contains a signature, else
 * NGX_HTTP_SKEL_CLEAN. Never allocates, never reads outside [data, data+len),
 * and is safe on (NULL, 0).
 */
ngx_int_t ngx_http_skel_scan(u_char *data, size_t len);


/*
 * Validate the rule table against the cross-buffer seam carry. Returns NGX_OK
 * if every rule fits (see NGX_HTTP_SKEL_MAX_RULE_LEN), NGX_ERROR otherwise.
 * Call once at config time; a failure means a rule is too long to be caught
 * when split across a buffer boundary.
 */
ngx_int_t ngx_http_skel_scan_rules_valid(void);


/*
 * Streaming-scan state, caller-owned, zero-initialized before the first piece.
 *
 *   hold      raw trailing partial percent-escape (0..NGX_HTTP_SKEL_HOLD_MAX
 *             bytes) carried from the previous piece so an escape split at a
 *             piece boundary decodes from the same state as an unsplit one.
 *   tail      last DECODED bytes of the previous piece (up to
 *             NGX_HTTP_SKEL_MAX_RULE_LEN - 1), for catching a rule whose
 *             decoded form straddles the seam.
 *
 * Both carries are DECODED-side state: the decode happens once per piece, and
 * matching is over decoded bytes on both sides of every seam. This is what
 * makes the streaming verdict independent of where the piece boundaries fall
 * (issues.md H2 -- the previous raw-byte carry was not).
 */
typedef struct {
    u_char  hold[NGX_HTTP_SKEL_HOLD_MAX];
    size_t  hold_len;
    u_char  tail[NGX_HTTP_SKEL_MAX_RULE_LEN - 1];
    size_t  tail_len;
} ngx_http_skel_stream_t;


/*
 * Scan one piece of a stream. `st` is caller-owned state, updated in place;
 * zero it before the first piece. Any rule fully inside one piece is caught by
 * that piece; any rule straddling a piece boundary is caught by the decoded
 * seam carried in `st`. Returns NGX_HTTP_SKEL_MATCH as soon as a rule matches.
 */
ngx_int_t ngx_http_skel_scan_piece(ngx_http_skel_stream_t *st,
    u_char *data, size_t len);


/*
 * Flush end-of-stream state after the LAST piece. If the stream ended mid
 * percent-escape, the held raw bytes are decoded and matched now. Callers that
 * scan a bounded prefix and stop MUST call this once after the final
 * ngx_http_skel_scan_piece() to avoid missing a rule that ends in a partial
 * escape at the very end of the input.
 */
ngx_int_t ngx_http_skel_stream_final(ngx_http_skel_stream_t *st);


#endif /* _NGX_HTTP_SKEL_SCAN_H_INCLUDED_ */
