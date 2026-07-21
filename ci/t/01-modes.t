# Modes, status codes, and directive inheritance.
#
# NB: the module runs in the PRECONTENT phase. The `return` directive finalizes
# in REWRITE, BEFORE precontent, so a tested location must use a real content
# handler (empty_gif) or the handler never runs and every test passes vacuously.
use Test::Nginx::Socket 'no_plan';

repeat_each(1);
no_long_string();
run_tests();

__DATA__

=== TEST 1: block mode returns 403 on a rule match
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 403

=== TEST 2: block mode passes a request with no match
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?sort=order&page=2
--- error_code: 200

=== TEST 3: detect mode logs but never blocks
--- config
    location /t { skel detect; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 200
--- error_log
skel: match

=== TEST 4: off mode does not even scan
--- config
    location /t { skel off; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 200
--- no_error_log
skel: match

=== TEST 5: default (no directive) is off
--- config
    location /t { empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 200

=== TEST 6: skel_status overrides the block status
--- config
    location /t { skel block; skel_status 404; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 404

=== TEST 7: skel_status 429
--- config
    location /t { skel block; skel_status 429; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 429

=== TEST 8: a location inherits the server-level mode
--- config
    skel block;
    location /t { empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 403

=== TEST 9: a location overrides the server-level mode
--- config
    skel block;
    location /t { skel off; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 200

=== TEST 10: detect mode logs but never blocks a body match (405 is empty_gif rejecting POST, proving skel let the request through instead of blocking)
--- config
    location /d { skel detect; skel_max_body 8k; empty_gif; }
--- request eval
"POST /d\n" . "SKEL-MARKER"
--- error_code: 405
--- error_log
skel: match
