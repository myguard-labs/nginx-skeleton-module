/*
 * Copyright (C) 2026 Thijs Eilander
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Unit tests for the scan core (src/ngx_http_skel_scan.c).
 *
 * WHY THIS EXISTS ALONGSIDE ci/t/ AND ci/fuzz/
 *
 *   ci/t, Test::Nginx    drives the module through a live nginx. It proves the
 *                        request plumbing, but it can only reach the scan core
 *                        through an HTTP request, so the boundary at
 *                        NGX_HTTP_SKEL_SCAN_MAX is awkward to hit and a
 *                        piece boundary is not addressable at all.
 *   ci/fuzz targets      drive the same code with random bytes. They prove the
 *                        core does not CRASH and (in fuzz_body) that split
 *                        input agrees with whole input -- but a fuzzer asserts
 *                        invariants, not VALUES. "the cap truncates at exactly
 *                        NGX_HTTP_SKEL_SCAN_MAX" is not something it can state.
 *   this file            states values, at named boundaries, with no nginx
 *                        process and no network, in well under a second.
 *
 * It links the REAL src/ngx_http_skel_scan.c and the REAL nginx
 * src/core/ngx_string.c (via ci/tests/unit/run.sh), exactly as the fuzz targets
 * do. There is deliberately NO shim reimplementation of ngx_unescape_uri():
 * the decoder is the thing most likely to disagree with nginx, and a test that
 * asserts against a private copy of it would assert that the copy is
 * self-consistent, which is worth nothing. ci/fuzz/ngx_stubs.c supplies the
 * allocator/log symbols that ngx_string.c drags in, and aborts if the scan path
 * ever actually reaches one.
 *
 * PORTABILITY: keep every case free of host assumptions -- no sizeof-dependent
 * expected values, no signed-char comparisons, no pointer-width arithmetic in
 * an expectation. This is a CONVENTION, not something CI enforces: every job
 * in this repo runs amd64, where size_t is 8 bytes and char is signed.
 *
 * Two non-amd64 legs used to exist and both were removed on 2026-08-01 (see
 * memory issues.md). qemu-s390x never once reached this code: the build host's
 * runner slots cannot emulate s390x. -m32 did work; it went on the same call.
 *
 * Three separate properties went with them, and they are worth keeping apart --
 * s390x happened to carry two of them at once, which is not the same as their
 * being one axis:
 *
 *   * pointer/size_t width. Reproduce natively: `CC="gcc -m32"`.
 *   * plain `char` signedness, which is implementation-defined and independent
 *     of byte order. Reproduce natively too: `CC="gcc -funsigned-char"` (or
 *     -fsigned-char) needs no emulation at all, so a derived module that
 *     classifies high-bit bytes has no excuse for leaving it untested.
 *   * byte order. This one genuinely needs a big-endian target, and it is the
 *     property nothing here can reproduce. It stays latent while the scan core
 *     decodes no multi-byte integers off the wire, and becomes live the moment
 *     a derived module parses a length prefix or a binary protocol -- that
 *     module needs its own leg.
 *
 * Extend: add a CASE() function and one line in main(). Keep each case
 * asserting a value the CORRECT implementation produces and a BROKEN one does
 * not -- ci/tests/unit/run.sh's header lists the mutations every case here was
 * seen red against.
 */

#include "ngx_http_skel_scan.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


static int  failures;
static int  checks;


static void
check(int ok, const char *what)
{
    checks++;
    if (ok) {
        printf("ok   %s\n", what);
        return;
    }
    printf("FAIL %s\n", what);
    failures++;
}


/* Scan a NUL-terminated C literal. The core takes (u_char *, len) and never
 * looks for a terminator, so the length is the string length -- never
 * sizeof(), which would feed the NUL in as a scanned byte and quietly change
 * what the decoder sees at the end of the buffer. */
static ngx_int_t
scan_str(const char *s)
{
    u_char  buf[NGX_HTTP_SKEL_SCAN_MAX * 2];
    size_t  n;

    n = strlen(s);
    if (n > sizeof(buf)) {
        n = sizeof(buf);
    }
    memcpy(buf, s, n);

    return ngx_http_skel_scan(buf, n);
}


/*
 * Drive `s` through the streaming API split at `at`, plus the mandatory
 * end-of-stream flush. Returns MATCH if either half or the flush matched.
 */
static ngx_int_t
scan_split(const u_char *s, size_t len, size_t at)
{
    ngx_http_skel_stream_t  st;
    ngx_int_t               rc;
    u_char                  a[NGX_HTTP_SKEL_SCAN_MAX];
    u_char                  b[NGX_HTTP_SKEL_SCAN_MAX];

    memset(&st, 0, sizeof(st));

    /*
     * Both halves must fit. Every current caller passes a short hand-picked
     * literal, so this cannot fire today -- but this file's header invites new
     * cases, and a longer string added to probe a boundary would smash two
     * stack buffers inside the harness. A test harness that corrupts its own
     * stack does not report a failure, it reports nonsense, and the bug looks
     * like it is in the code under test.
     */
    if (at > sizeof(a) || len < at || len - at > sizeof(b)) {
        fprintf(stderr, "scan_split: input of %zu split at %zu does not fit "
                        "the %zu-byte halves\n", len, at, sizeof(a));
        abort();
    }

    memcpy(a, s, at);
    memcpy(b, s + at, len - at);

    rc = ngx_http_skel_scan_piece(&st, a, at);
    if (rc != NGX_HTTP_SKEL_CLEAN) {
        return rc;
    }

    rc = ngx_http_skel_scan_piece(&st, b, len - at);
    if (rc != NGX_HTTP_SKEL_CLEAN) {
        return rc;
    }

    return ngx_http_skel_stream_final(&st);
}


/* --- cases ---------------------------------------------------------------- */

/*
 * The baseline pair. Both directions are asserted on purpose: a matcher that
 * returns MATCH unconditionally passes every other case in this file, so the
 * clean case is what makes the rest of them mean anything.
 */
static void
case_baseline(void)
{
    check(ngx_http_skel_scan(NULL, 0) == NGX_HTTP_SKEL_CLEAN,
          "(NULL, 0) is clean, not a crash");
    check(scan_str("") == NGX_HTTP_SKEL_CLEAN, "empty input is clean");
    check(scan_str("nothing to see here") == NGX_HTTP_SKEL_CLEAN,
          "benign input is clean");
    check(scan_str("xx skel-marker xx") == NGX_HTTP_SKEL_MATCH,
          "plain marker matches");
}


/*
 * Normalization is the reason the decoder is production code. Each of these
 * would be missed by a raw substring pass, which is precisely the bypass the
 * normalize stage exists to close.
 */
static void
case_normalize(void)
{
    check(scan_str("SKEL-MARKER") == NGX_HTTP_SKEL_MATCH,
          "uppercase marker matches (lowercased before match)");
    check(scan_str("MiXeD skEl-MaRkEr") == NGX_HTTP_SKEL_MATCH,
          "mixed-case marker matches");
    check(scan_str("%73kel-marker") == NGX_HTTP_SKEL_MATCH,
          "percent-encoded first byte matches");
    check(scan_str("%73%6b%65%6c%2d%6d%61%72%6b%65%72") == NGX_HTTP_SKEL_MATCH,
          "fully percent-encoded marker matches");
    /* Double-encoding is NOT decoded twice, and must not be: nginx decodes
     * once, so a module that decoded twice would match strings the server
     * itself never sees as a marker -- a false positive, and a divergence from
     * the bytes the request is actually served with. */
    check(scan_str("%2573kel-marker") == NGX_HTTP_SKEL_CLEAN,
          "double-encoded marker does NOT match (single decode, like nginx)");
}


/*
 * The cap is a hard, documented truncation (NGX_HTTP_SKEL_SCAN_MAX). Asserting
 * BOTH sides of it is the point: "past the cap is not scanned" alone would also
 * pass on an implementation that scanned nothing at all.
 *
 * The arithmetic is written from the constant, never from the literal 8192, so
 * raising the cap in the header cannot leave a stale expectation here.
 */
static void
case_cap_boundary(void)
{
    static const char  marker[] = "skel-marker";
    const size_t       mlen = sizeof(marker) - 1;
    u_char             buf[NGX_HTTP_SKEL_SCAN_MAX + 64];

    /* Marker ending on the LAST byte inside the window: must match. */
    memset(buf, 'a', sizeof(buf));
    memcpy(buf + NGX_HTTP_SKEL_SCAN_MAX - mlen, marker, mlen);
    check(ngx_http_skel_scan(buf, sizeof(buf)) == NGX_HTTP_SKEL_MATCH,
          "marker ending exactly at the cap matches");

    /* Marker starting one byte past the window: must NOT match -- this is the
     * documented truncation, and a caller that needs to see past it is
     * required to pre-chunk with the streaming API. */
    memset(buf, 'a', sizeof(buf));
    memcpy(buf + NGX_HTTP_SKEL_SCAN_MAX, marker, mlen);
    check(ngx_http_skel_scan(buf, sizeof(buf)) == NGX_HTTP_SKEL_CLEAN,
          "marker starting past the cap is truncated away");

    /* One byte overlapping the boundary is still short of a full marker inside
     * the window, so it must not match either. This is the case that catches an
     * off-by-one in the cap clamp -- the two above both survive a +-1 error. */
    memset(buf, 'a', sizeof(buf));
    memcpy(buf + NGX_HTTP_SKEL_SCAN_MAX - mlen + 1, marker, mlen);
    check(ngx_http_skel_scan(buf, sizeof(buf)) == NGX_HTTP_SKEL_CLEAN,
          "marker straddling the cap by one byte does not match");
}


/*
 * THE LOAD-BEARING PROPERTY: a streaming verdict must not depend on where the
 * caller's buffer boundaries happen to fall. Chain-buffer sizes are chosen by
 * nginx and by the client's framing, so a verdict that changes with the split
 * is a deterministic bypass an attacker picks by choosing a body size.
 *
 * ci/fuzz/fuzz_body.c asserts this same property over random bytes. Here it is
 * asserted EXHAUSTIVELY over the split points of a handful of hand-picked
 * inputs, including the escape-straddling ones a fuzzer reaches only by luck.
 */
static void
case_split_invariance(void)
{
    static const char *const  inputs[] = {
        "xx skel-marker xx",             /* plain, split anywhere */
        "xx %73kel-marker xx",           /* escape before the marker */
        "xx skel-marke%72 xx",           /* escape inside the marker */
        "xx skel-marke%72",              /* escape at the very end (needs the
                                          * stream_final() flush) */
        "%73%6b%65%6c%2d%6d%61%72%6b%65%72",  /* every byte an escape */
        "xx clean text only xx",         /* the clean control: invariance must
                                          * hold in the CLEAN direction too, or
                                          * this case would pass on a matcher
                                          * that always says MATCH */
    };
    size_t  i, at, len;
    int     bad;

    for (i = 0; i < sizeof(inputs) / sizeof(inputs[0]); i++) {
        const u_char  *s = (const u_char *) inputs[i];
        ngx_int_t      whole;
        char           label[160];

        len = strlen(inputs[i]);
        whole = scan_str(inputs[i]);
        bad = 0;

        for (at = 1; at < len; at++) {
            if (scan_split(s, len, at) != whole) {
                printf("     split at %lu disagrees with whole for \"%s\"\n",
                       (unsigned long) at, inputs[i]);
                bad = 1;
            }
        }

        snprintf(label, sizeof(label),
                 "every split of \"%s\" agrees with the whole-buffer verdict",
                 inputs[i]);
        check(!bad, label);
    }
}


/*
 * The hold/flush half of the streaming contract.
 *
 * SCOPE, stated honestly because it is easy to overclaim here: with the
 * SHIPPED rule table, ngx_http_skel_stream_final() can never be the call that
 * produces a MATCH. The held bytes are by definition an INCOMPLETE percent
 * escape (at most "%" or "%A"), and no shipped rule ends in those literal
 * bytes -- verified by mutation: stubbing final() to `return CLEAN`
 * immediately leaves all 22 checks green (see ci/tests/unit/run.sh's SEEN RED
 * list, which used to claim otherwise). It becomes matchable the moment a
 * derived module adds a rule containing a literal '%'.
 *
 * So what is asserted here is what IS observable and IS load-bearing today:
 * the piece must HOLD an open escape rather than decide it (deciding it early
 * is the H2 bug -- decoding from the wrong escape state), and final() must
 * CLEAR the hold.
 *
 * Why clearing matters, stated precisely -- an earlier version of this comment
 * claimed the module reuses one state struct across streams, and it does not:
 * ngx_http_skel_scan_body() declares `st` as a stack local and ngx_memzero()s
 * it per call (module.c), so today no request can inherit another's hold. The
 * assertion guards the CONTRACT, not a live bug: the header documents `st` as
 * caller-owned and reusable after final(), and a derived module that hoists it
 * to a request ctx or a long-lived struct -- the natural move when a scan spans
 * several body handlers -- gets that reuse for free. A final() that left
 * hold_len set would then prepend one stream's held bytes to the next one's
 * first piece. Keep the assertion; it is what makes the documented contract
 * true rather than aspirational.
 */
static void
case_stream_hold_and_flush(void)
{
    ngx_http_skel_stream_t  st;
    static const char       in[] = "xx skel-marke%72";
    u_char                  buf[sizeof(in)];
    size_t                  len = sizeof(in) - 1;
    ngx_int_t               rc;

    memset(&st, 0, sizeof(st));
    memcpy(buf, in, len);

    /* One piece, whole input -- the trailing "%72" is a COMPLETE escape, so it
     * decodes within the piece and no flush is needed. */
    check(ngx_http_skel_scan_piece(&st, buf, len) == NGX_HTTP_SKEL_MATCH,
          "complete trailing escape is decided by the piece itself");

    /* Now cut the input so the escape is left OPEN at end-of-stream. */
    memset(&st, 0, sizeof(st));
    rc = ngx_http_skel_scan_piece(&st, buf, len - 1);   /* ends at "...%7" */
    check(rc == NGX_HTTP_SKEL_CLEAN,
          "an open trailing escape is held, not decided, by the piece");
    check(st.hold_len > 0, "the open escape is actually held in st.hold");

    (void) ngx_http_skel_stream_final(&st);
    check(st.hold_len == 0,
          "final() clears the hold, so a reused state cannot leak bytes "
          "into the next stream");
}


/*
 * The seam carry has a documented bound (NGX_HTTP_SKEL_MAX_RULE_LEN). The
 * config-time validator is what turns "a rule got longer than the carry" from a
 * silent bypass into a startup failure, so assert it agrees with the shipped
 * table. Derived modules add rules; this is the check that goes red for them.
 */
static void
case_rules_fit_the_carry(void)
{
    check(ngx_http_skel_scan_rules_valid() == NGX_OK,
          "every shipped rule fits the cross-seam carry");
}


int
main(void)
{
    case_baseline();
    case_normalize();
    case_cap_boundary();
    case_split_invariance();
    case_stream_hold_and_flush();
    case_rules_fit_the_carry();

    printf("\n%d check(s), %d failure(s)\n", checks, failures);

    /* A run that asserted NOTHING is a failure, not a pass: the whole point of
     * this binary is that it cannot go green by doing nothing (the exact shape
     * ci/linter/selftest.sh guards against on the lint side). */
    if (checks == 0) {
        printf("FAIL: no checks ran\n");
        return 1;
    }

    return failures ? 1 : 0;
}
