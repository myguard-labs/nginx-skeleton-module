/*
 * Copyright (C) 2026 Thijs Eilander
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * ngx_http_skel_scan -- the scan core (see ngx_http_skel_scan.h).
 *
 * Two stages, both bounded and allocation-free:
 *
 *   1. normalize: percent-decode with nginx's REAL ngx_unescape_uri() and
 *      lowercase, into a fixed stack buffer. Using the production decoder (not
 *      a hand-rolled one) means the bytes we match are exactly the bytes nginx
 *      would act on -- a decoder that disagrees with nginx's is a bypass.
 *
 *   2. match: a plain substring pass over a compiled rule table.
 *
 * The table below matches a single placeholder marker ("SKEL-MARKER"). It is
 * NOT meant to be useful on its own -- replace it with your module's real
 * matching logic. It exists only to give the CI harness (tests/fuzz) something
 * concrete to exercise, so the skeleton builds, tests, and fuzzes cleanly
 * before you have written a single line of your own logic.
 *
 * The contract to keep is the one the fuzzer relies on: pure (u_char *, len)
 * in, verdict out, no request state, no allocation, no read past the input.
 *
 * Scale note: this is O(n*m) over the table. Fine for a handful of rules; a
 * real module with hundreds of rules wants Aho-Corasick. If you build one,
 * make each accepting state carry a SET of categories (a bitmask), not one --
 * storing a single category per state and taking first-writer-wins silently
 * drops a short rule that shares an accepting state with a longer one from
 * another category. Catch that class of bug with a differential fuzz harness
 * (naive matcher vs AC, same inputs).
 */

#include "ngx_http_skel_scan.h"


typedef struct {
    const char  *pat;
    size_t       len;
} ngx_http_skel_rule_t;


/*
 * Rule table. Replace with the real matching logic for your module -- a
 * signature list, a structured parser, whatever the module actually needs.
 * This single entry only exists so the skeleton's tests and fuzz harness have
 * something concrete to exercise out of the box.
 */
#define ngx_http_skel_rule(s)  { (s), sizeof(s) - 1 }

static const ngx_http_skel_rule_t  ngx_http_skel_rules[] = {
    ngx_http_skel_rule("skel-marker"),
};

#define NGX_HTTP_SKEL_NRULES                                                 \
    (sizeof(ngx_http_skel_rules) / sizeof(ngx_http_skel_rules[0]))


static size_t ngx_http_skel_normalize(u_char *dst, u_char *src, size_t len);
static ngx_int_t ngx_http_skel_match(u_char *buf, size_t n);


/*
 * Validate that every rule fits the cross-buffer seam carry. Called once at
 * config time (ngx_http_skel_init).
 *
 * ngx_http_skel_scan_piece() carries only NGX_HTTP_SKEL_MAX_RULE_LEN - 1
 * DECODED bytes across a chain-buffer / file-read boundary. A rule copy split
 * exactly across such a seam is only caught if its whole DECODED form fits in
 * that carry. Because the carry now holds decoded (not raw) bytes -- see the
 * decode-once seam in ngx_http_skel_scan_piece() -- the bound is on the decoded
 * rule length directly, not its worst-case 3x raw span.
 *
 * The shipped "skel-marker" rule (11 bytes) fits with room to spare. This check
 * exists for the DERIVED module: add a rule longer than the carry and forget to
 * raise NGX_HTTP_SKEL_MAX_RULE_LEN, and a copy of it straddling a buffer
 * boundary would be silently missed -- a deterministic bypass. Failing config
 * load loudly here turns that latent bypass into an immediate startup error.
 */
ngx_int_t
ngx_http_skel_scan_rules_valid(void)
{
    ngx_uint_t  i;

    for (i = 0; i < NGX_HTTP_SKEL_NRULES; i++) {
        if (ngx_http_skel_rules[i].len > NGX_HTTP_SKEL_MAX_RULE_LEN - 1) {
            return NGX_ERROR;
        }
    }

    return NGX_OK;
}


/*
 * Match a table rule inside an ALREADY-DECODED, already-lowercased buffer.
 * Shared by the single-shot scan (which decodes first) and the streaming seam
 * (which decodes once and matches the decoded bytes directly, so a rule is
 * never re-decoded from a different escape state on either side of a seam).
 */
static ngx_int_t
ngx_http_skel_match(u_char *buf, size_t n)
{
    size_t                       i;
    const ngx_http_skel_rule_t  *rule;

    for (i = 0; i < NGX_HTTP_SKEL_NRULES; i++) {
        rule = &ngx_http_skel_rules[i];

        if (rule->len > n) {
            continue;
        }

        /* ngx_strlcasestrn takes the last-index form (len - 1) and needs the
         * haystack's remaining length, so bound it to buf + n explicitly --
         * buf is NOT NUL-terminated. */
        if (ngx_strlcasestrn(buf, buf + n, (u_char *) rule->pat,
                             rule->len - 1) != NULL)
        {
            return NGX_HTTP_SKEL_MATCH;
        }
    }

    return NGX_HTTP_SKEL_CLEAN;
}


ngx_int_t
ngx_http_skel_scan(u_char *data, size_t len)
{
    u_char  buf[NGX_HTTP_SKEL_SCAN_MAX];
    size_t  n;

    if (data == NULL || len == 0) {
        return NGX_HTTP_SKEL_CLEAN;
    }

    /*
     * Bound the input to the working buffer. Decoding only ever shrinks, so
     * this cap is sufficient -- dst can never outrun buf.
     *
     * This IS a truncation: anything past NGX_HTTP_SKEL_SCAN_MAX in this one
     * call is simply not looked at. We deliberately do NOT log it here --
     * this TU's contract (see ci/fuzz/ngx_stubs.c) is that the scan core never
     * allocates or logs, which is what lets the fuzzer link it directly
     * against nginx's real ngx_string.c without pulling in the pool/log/cycle
     * machinery. A caller in request-handler context that cares whether
     * truncation happened can compare `len` before/after this call. A caller
     * that needs to cover more than one cap's worth of input (a large body) is
     * expected to pre-chunk with the tail-carry pattern in
     * ngx_http_skel_scan_piece(), not to make this cap bigger.
     */
    if (len > NGX_HTTP_SKEL_SCAN_MAX) {
        len = NGX_HTTP_SKEL_SCAN_MAX;
    }

    n = ngx_http_skel_normalize(buf, data, len);

    return ngx_http_skel_match(buf, n);
}


/*
 * Percent-decode + lowercase src into dst; returns the decoded length.
 *
 * dst must have room for `len` bytes: ngx_unescape_uri() only ever shrinks
 * (3 bytes "%41" -> 1 byte "A"), so the decoded form cannot exceed the input.
 *
 * ngx_unescape_uri() advances the dst/src pointers it is given, which is why
 * they are taken by address here. NGX_UNESCAPE_URI stops at '?' and '#'; we
 * want the query string scanned too, so pass 0 (decode everything, the same
 * type nginx uses for args).
 */
static size_t
ngx_http_skel_normalize(u_char *dst, u_char *src, size_t len)
{
    u_char  *d, *s, *end;

    d = dst;
    s = src;

    ngx_unescape_uri(&d, &s, len, 0);

    end = d;

    for (d = dst; d < end; d++) {
        *d = ngx_tolower(*d);
    }

    return (size_t) (end - dst);
}


/*
 * Number of RAW trailing bytes that form an INCOMPLETE percent-escape at the
 * end of `data` -- the bytes ngx_unescape_uri() would still be mid-token on if
 * the input stopped here. 0, 1 (ended in sw_quoted, "...%"), or 2 (ended in
 * sw_quoted_second, "...%A"). These must be held back from this piece's decode
 * and prepended to the next piece, so the escape is decoded from the same state
 * whether the input arrives whole or split at that exact byte.
 *
 * A naive last-two-bytes lookback is WRONG: in "%%A" the second '%' is consumed
 * as the (invalid) follower of the first, so the trailing "%A" is NOT an open
 * token and 'A' is literal. Whether a trailing '%' opens a token depends on the
 * decoder's state arriving there, so this walks ngx_unescape_uri()'s exact
 * three-state machine (type 0 path) over the whole window and reports only the
 * END state -- it decides where a token is still open, never what it decodes to.
 */
static size_t
ngx_http_skel_partial_escape(const u_char *data, size_t len)
{
    size_t  i;
    u_char  ch, c;
    enum { sw_usual = 0, sw_quoted, sw_quoted_second } state = sw_usual;

    for (i = 0; i < len; i++) {
        ch = data[i];

        switch (state) {
        case sw_usual:
            if (ch == '%') {
                state = sw_quoted;
            }
            break;

        case sw_quoted:
            c = (u_char) (ch | 0x20);
            if ((ch >= '0' && ch <= '9') || (c >= 'a' && c <= 'f')) {
                state = sw_quoted_second;
            } else {
                /* invalid quoted char: '%' dropped, this char emitted, reset */
                state = sw_usual;
            }
            break;

        case sw_quoted_second:
            /* completes the token (valid or not); always back to usual */
            state = sw_usual;
            break;
        }
    }

    if (state == sw_quoted) {
        return 1;   /* trailing "%" with no follower yet */
    }
    if (state == sw_quoted_second) {
        return 2;   /* trailing "%A" awaiting its second hex digit */
    }
    return 0;
}


ngx_int_t
ngx_http_skel_scan_piece(ngx_http_skel_stream_t *st, u_char *data, size_t len)
{
    u_char  raw[NGX_HTTP_SKEL_HOLD_MAX + NGX_HTTP_SKEL_SCAN_MAX];
    u_char  dec[NGX_HTTP_SKEL_SCAN_MAX];
    u_char  seam[(NGX_HTTP_SKEL_MAX_RULE_LEN - 1) + NGX_HTTP_SKEL_SCAN_MAX];
    size_t  raw_len, hold_next, decodable, ndec, chunk, seam_len, keep;
    ngx_int_t  rc;

    if (len == 0) {
        return NGX_HTTP_SKEL_CLEAN;
    }

    /*
     * Process the raw stream in windows small enough that the held partial
     * escape plus the window fits `raw`. Each window is: any partial-escape
     * bytes carried from the previous window (st->hold), then this slice of
     * `data`. We split a fresh trailing partial escape off the END of the
     * window and hold it for next time, so ngx_unescape_uri() only ever sees
     * COMPLETE tokens and decodes a given byte-run identically no matter where
     * the piece boundary fell (H2: the raw-byte carry could not reconstruct the
     * decoder's mid-token state; carrying the open token itself does).
     */
    while (len > 0) {

        raw_len = st->hold_len;
        if (raw_len) {
            ngx_memcpy(raw, st->hold, raw_len);
        }

        /* Cap the slice so hold + slice never exceeds the decode buffer:
         * decoding only shrinks, so dec[NGX_HTTP_SKEL_SCAN_MAX] then always
         * holds the result. */
        chunk = len;
        if (chunk > NGX_HTTP_SKEL_SCAN_MAX - raw_len) {
            chunk = NGX_HTTP_SKEL_SCAN_MAX - raw_len;
        }
        ngx_memcpy(raw + raw_len, data, chunk);
        raw_len += chunk;

        data += chunk;
        len -= chunk;

        /*
         * Hold back a trailing incomplete escape. This ALWAYS happens at a
         * window/piece edge, never gated on "more input follows": scan_piece
         * cannot know whether another piece is coming, so an unfinished "%" at
         * the end of a piece is carried in st->hold and prepended to the next
         * piece. The caller signals true end-of-stream with
         * ngx_http_skel_stream_final(), which decodes and matches any escape
         * still held after the last piece.
         */
        hold_next = ngx_http_skel_partial_escape(raw, raw_len);

        /*
         * hold_next may equal raw_len (a tiny slice that is ENTIRELY an open
         * escape, e.g. a "%7" slice). Holding the whole window is correct: the
         * next piece appends to it, and the loop still makes progress because
         * `data`/`len` were already advanced past this slice above. decodable
         * is then 0 and this window simply decodes nothing.
         */
        decodable = raw_len - hold_next;

        st->hold_len = hold_next;
        if (hold_next) {
            ngx_memcpy(st->hold, raw + decodable, hold_next);
        }

        if (decodable == 0) {
            continue;
        }

        ndec = ngx_http_skel_normalize(dec, raw, decodable);
        if (ndec == 0) {
            continue;
        }

        /*
         * Match over (previous decoded tail ++ this window's decoded bytes) as
         * one contiguous buffer. Prepending the carried tail catches a rule
         * whose decoded form straddles the boundary -- INCLUDING one that spans
         * three or more small windows, because the tail is refreshed from the
         * END of this combined buffer, so an unmatched prefix of a rule slides
         * forward window by window until the whole rule is present. Both sides
         * are already decoded, so nothing is re-decoded from a wrong escape
         * state across the seam -- that was the H2 bug.
         */
        seam_len = st->tail_len;
        if (seam_len) {
            ngx_memcpy(seam, st->tail, seam_len);
        }
        ngx_memcpy(seam + seam_len, dec, ndec);
        seam_len += ndec;

        rc = ngx_http_skel_match(seam, seam_len);
        if (rc != NGX_HTTP_SKEL_CLEAN) {
            return rc;
        }

        /* Refresh the decoded tail from the END of the combined buffer so the
         * next window continues the slide with full context. */
        keep = seam_len;
        if (keep > NGX_HTTP_SKEL_MAX_RULE_LEN - 1) {
            keep = NGX_HTTP_SKEL_MAX_RULE_LEN - 1;
        }
        ngx_memcpy(st->tail, seam + seam_len - keep, keep);
        st->tail_len = keep;
    }

    return NGX_HTTP_SKEL_CLEAN;
}


ngx_int_t
ngx_http_skel_stream_final(ngx_http_skel_stream_t *st)
{
    u_char     dec[NGX_HTTP_SKEL_HOLD_MAX];
    u_char     seam[2 * (NGX_HTTP_SKEL_MAX_RULE_LEN - 1)];
    size_t     ndec, seam_len, chunk;
    ngx_int_t  rc;

    /*
     * Flush a held partial escape at end-of-stream. If the last real bytes were
     * an unfinished "%" token, ngx_unescape_uri() would emit them per its
     * invalid-quoted rules; decode them now (as a terminal token, no more input
     * follows) and run them through the seam so a rule ending in those bytes is
     * still caught.
     */
    if (st->hold_len == 0) {
        return NGX_HTTP_SKEL_CLEAN;
    }

    ndec = ngx_http_skel_normalize(dec, st->hold, st->hold_len);
    st->hold_len = 0;

    if (ndec == 0) {
        return NGX_HTTP_SKEL_CLEAN;
    }

    if (st->tail_len) {
        seam_len = st->tail_len;
        ngx_memcpy(seam, st->tail, seam_len);
    } else {
        seam_len = 0;
    }

    chunk = ndec;
    if (chunk > NGX_HTTP_SKEL_MAX_RULE_LEN - 1) {
        chunk = NGX_HTTP_SKEL_MAX_RULE_LEN - 1;
    }
    ngx_memcpy(seam + seam_len, dec, chunk);
    seam_len += chunk;

    rc = ngx_http_skel_match(seam, seam_len);
    if (rc != NGX_HTTP_SKEL_CLEAN) {
        return rc;
    }

    return NGX_HTTP_SKEL_CLEAN;
}
