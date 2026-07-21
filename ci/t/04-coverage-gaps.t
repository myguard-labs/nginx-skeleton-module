# Targeted tests for branches that 01-03 exercise only incidentally or not at
# all.
#
# 2026-07-14: closed the `rc >= NGX_HTTP_SPECIAL_RESPONSE` branch in
# ngx_http_skel_handler -- a client that declares a Content-Length larger than
# the bytes it actually sends, then closes the connection, makes
# ngx_http_read_client_request_body() itself fail. See t/05-body-abort.t.
#
# 2026-07-14 follow-up: closed the `b->in_file` half of the
# `if (b->in_file || ngx_buf_special(b))` branch (src/ngx_http_skel_module.c,
# ngx_http_skel_scan_body) -- a body forced to spool to disk via
# `client_body_in_file_only on` genuinely sets buf->in_file on every chain
# link, taking the loop's very first iteration. See TEST 7 below.
#
# 2026-07-15 (audit F2/F3): `ngx_http_skel_scan_body` used to (a) stop dead on
# the first `in_file` buf and return CLEAN without reading the spooled temp
# file -- an unconditional inspection bypass, just make the body spool -- and
# (b) scan each in-memory chain buf independently, so a rule split across two
# bufs was invisible. Fixed by reading the spooled temp file with
# ngx_read_file() up to `max` bytes, and by carrying a small tail of raw bytes
# across buffer/file-read boundaries (ngx_http_skel_scan_piece) so a
# boundary-straddling rule is still caught. TEST 7 below now expects a BLOCK,
# not a bypass. `ngx_http_skel_handler`'s body-read gate also used to be a
# POST/PUT/PATCH method allowlist (F3) -- any other body-bearing method (DELETE
# included) skipped scanning entirely; fixed to gate on body presence
# (Content-Length/chunked) instead. See t/05-body-abort.t's sibling additions
# below for the DELETE case and the cross-buffer-split case.
#
# 2026-07-15: dropped the gcov/lcov/Coveralls coverage CI job entirely (branch
# coverage plateaued at 88.6%, remaining gaps are allocator-failure paths and
# nginx-core-internal buf-chain shapes a black-box HTTP client cannot produce
# -- see below). The debug-only fault-injection hook that used to close the
# three ngx_pcalloc()/ngx_array_push() NULL-return sites, and the tests that
# drove it (t/06-09), were removed with it -- they existed only to feed the
# coverage number, not to catch a real bug a real client could trigger.
#
# What is still intentionally NOT here (deliberately left untested):
#   - the zero-length-buf `continue` in ngx_http_skel_scan_body's chain loop
#     (src/ngx_http_skel_module.c, search `if (b->last <= b->pos)`) -- whether
#     a buf in the body chain is empty is decided by nginx's internal
#     body-buffering boundaries, not by anything a black-box HTTP client
#     controls. Tried and ruled out: chunked transfer-encoding with a leading
#     zero-size chunk gets rejected by nginx's own chunked-body parser before
#     reaching this code, so it doesn't produce the target buf shape either.
#   - the three ngx_pcalloc()/ngx_array_push() NULL-return paths (ctx alloc,
#     loc-conf alloc, phase-handler array push) -- only a real nginx pool
#     allocator failure reaches them, which no HTTP client can trigger.
use Test::Nginx::Socket 'no_plan';

repeat_each(1);
no_long_string();
run_tests();

__DATA__

=== TEST 1: subrequest does not re-scan (r != r->main short-circuit)
--- config
    location /t { skel block; empty_gif; }
    location /main.html {
        ssi on;
        default_type text/html;
        root html;
    }
--- user_files
>>> main.html
before-[<!--#include virtual="/t?id=SKEL-MARKER" -->]-after
--- request
GET /main.html
--- error_code: 200
--- response_body_like: before-\[GIF89a

=== TEST 2: body read rejected by nginx itself short-circuits before our scan
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        client_max_body_size 10;
        empty_gif;
    }
--- request eval
"POST /t\n" . ("A" x 100)
--- error_code: 413

=== TEST 3: a large body split across multiple small buffers is still scanned end-to-end
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        client_body_buffer_size 64;
        empty_gif;
    }
--- request eval
"POST /t\n" . ("A" x 500) . "SKEL-MARKER"
--- error_code: 403

=== TEST 4: a User-Agent longer than the scan cap does not overrun (truncated, not crashed)
--- config
    large_client_header_buffers 4 32k;
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers eval
"User-Agent: " . ("B" x 9000)
--- error_code: 200

=== TEST 5: a marker placed just past the scan cap is NOT seen (documents the truncation boundary)
--- config
    large_client_header_buffers 4 32k;
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers eval
"User-Agent: " . ("B" x 8200) . "SKEL-MARKER"
--- error_code: 200

=== TEST 6: an empty User-Agent header value hits the zero-length scan guard
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers
User-Agent:
--- error_code: 200

=== TEST 7: a body forced to spool to disk is still scanned via the temp file (F2 -- used to be an inspection bypass; a spooled marker must now block same as an in-memory one)
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        client_body_in_file_only on;
        client_body_buffer_size 1;
        empty_gif;
    }
--- request eval
"POST /t\n" . "SKEL-MARKER"
--- error_code: 403

=== TEST 8: a spooled body without the marker still passes through (proves the temp-file read isn't just always-block)
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        client_body_in_file_only on;
        client_body_buffer_size 1;
        empty_gif;
    }
--- request eval
"POST /t\n" . ("A" x 200)
--- error_code: 405

=== TEST 9: a rule split exactly across two in-memory chain buffers is still caught (F2 cross-buffer straddle)
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        client_body_buffer_size 32;
        empty_gif;
    }
--- request eval
# "SKEL-" lands at the tail of one ~32-byte-boundary chunk, "MARKER" at the
# head of the next -- exercises ngx_http_skel_scan_piece's carried tail, not
# just a single oversized buffer.
"POST /t\n" . ("A" x 27) . "SKEL-MARKER" . ("B" x 50)
--- error_code: 403

=== TEST 10: DELETE with a body containing the marker is scanned and blocked the same as POST (F3 -- method allowlist used to skip DELETE entirely)
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        empty_gif;
    }
--- request eval
"DELETE /t\n" . "SKEL-MARKER"
--- error_code: 403

=== TEST 11: DELETE with a benign body passes through (proves TEST 10 isn't just always-block for DELETE)
--- config
    location /t {
        skel block;
        skel_max_body 8k;
        empty_gif;
    }
--- request eval
"DELETE /t\n" . "benign-ok"
--- error_code: 405

=== TEST 12: marker in a SECOND User-Agent line is scanned (G1 -- only the first line used to be checked, a trivial dup-header bypass)
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers
User-Agent: benign/1.0
User-Agent: SKEL-MARKER
--- error_code: 403

=== TEST 13: two benign User-Agent lines pass (proves TEST 12 isn't just always-block on duplicate headers)
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers
User-Agent: benign/1.0
User-Agent: also-benign/2.0
--- error_code: 200

=== TEST 14: a marker straddling the 8 KiB scan sub-chunk boundary inside one large body buffer is caught (G2 -- exercises ngx_http_skel_scan_piece's step-2 multi-chunk overlap, only reachable with skel_max_body > 8k and a single >8k in-memory buffer)
--- config
    location /t {
        skel block;
        skel_max_body 32k;
        client_body_buffer_size 64k;
        empty_gif;
    }
--- request eval
"POST /t\n" . ("A" x 8188) . "SKEL-MARKER" . ("B" x 100)
--- error_code: 403

=== TEST 15: a fully percent-encoded marker in the body is decoded once and blocked (H2 -- the streaming seam decodes complete tokens and matches decoded bytes; proves scan_body's decode path, not just raw matching)
--- config
    location /t {
        skel block;
        skel_max_body 4k;
        empty_gif;
    }
--- request eval
"POST /t\n" . ("A" x 50) . "%73%6b%65%6c%2d%6d%61%72%6b%65%72" . ("B" x 50)
--- error_code: 403

=== TEST 16: a marker split by a trailing partial percent-escape at the very end of the body is caught by the end-of-stream flush (H2 -- ngx_http_skel_stream_final)
--- config
    location /t {
        skel block;
        skel_max_body 4k;
        empty_gif;
    }
--- request eval
"POST /t\n" . ("skel-marke") . "%72"
--- error_code: 403
