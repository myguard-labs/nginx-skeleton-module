# The scan path: rules, the decoder, headers, and the body.
#
# The encoding cases are the load-bearing ones. A scanner that matches only the
# raw bytes is bypassed by `%73kel-marker`; one that decodes differently from
# nginx blocks traffic nginx would have routed elsewhere. Both directions are
# bugs, so both are pinned here.
use Test::Nginx::Socket 'no_plan';

repeat_each(1);
no_long_string();
run_tests();

__DATA__

=== TEST 1: marker in the query string
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?id=SKEL-MARKER
--- error_code: 403

=== TEST 2: percent-encoded marker is decoded before matching
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?id=%53KEL-%4dARKER
--- error_code: 403

=== TEST 3: matching is case-insensitive
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?id=SkEl-MaRkEr
--- error_code: 403

=== TEST 4: marker embedded in a larger value
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?x=prefix-SKEL-MARKER-suffix
--- error_code: 403

=== TEST 5: marker as a path segment
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t/SKEL-MARKER/more
--- error_code: 403

=== TEST 6: marker in a query value with surrounding punctuation
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?x=%24%7BSKEL-MARKER%7D
--- error_code: 403

=== TEST 7: marker in the User-Agent is scanned
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers
User-Agent: probe/1.0 SKEL-MARKER
--- error_code: 403

=== TEST 8: a benign User-Agent passes
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers
User-Agent: Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0
--- error_code: 200

=== TEST 9: marker in the request body is blocked
--- config
    location /t { skel block; skel_max_body 8k; empty_gif; }
--- request
POST /t
payload=SKEL-MARKER
--- error_code: 403

=== TEST 10: a benign body passes through (405 = empty_gif rejects POST)
--- config
    location /t { skel block; skel_max_body 8k; empty_gif; }
--- request
POST /t
name=alice&city=amsterdam
--- error_code: 405

=== TEST 11: skel_max_body 0 disables body scanning
--- config
    location /t { skel block; skel_max_body 0; empty_gif; }
--- request
POST /t
payload=SKEL-MARKER
--- error_code: 405

=== TEST 12: a body larger than the cap is NOT blocked for being big
--- config
    location /t { skel block; skel_max_body 64; empty_gif; }
--- request eval
"POST /t\n" . ("A" x 4096)
--- error_code: 405
