# False-positive negatives: ordinary traffic that must NEVER match.
#
# This is the file that keeps the rule table honest, and it is the reason a
# rule should be specific rather than a bare substring that shows up in
# ordinary traffic. A table that matches a fragment too short or too common
# passes 02-scan.t perfectly while matching a search box, a sort parameter, and
# half of every real site's traffic.
#
# Rule when adding a rule: add its FP-negative here in the SAME commit. A rule
# with no negative is a rule nobody has proved is safe to ship.
use Test::Nginx::Socket 'no_plan';

repeat_each(1);
no_long_string();
run_tests();

__DATA__

=== TEST 1: a word that shares a prefix with the marker ("skel" alone)
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?action=skel&id=7
--- error_code: 200

=== TEST 2: the word "marker" alone (an ordinary English word)
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?q=trail+marker+near+me
--- error_code: 200

=== TEST 3: prose containing both words, but not adjacent
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?q=skeleton+key+with+a+marker+pen
--- error_code: 200

=== TEST 4: a hyphenated word that looks similar but isn't the marker
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?name=self-marked
--- error_code: 200

=== TEST 5: a near-miss with an extra character inserted
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?q=skel-xmarker
--- error_code: 200

=== TEST 6: an ordinary absolute path unrelated to the marker
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?path=/usr/share/doc/readme.txt
--- error_code: 200

=== TEST 7: a dotted filename
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?file=archive.tar.gz&v=1.2.3
--- error_code: 200

=== TEST 8: an ordinary UA string
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?ok=1
--- more_headers
User-Agent: curl/8.5.0
--- error_code: 200

=== TEST 9: a template-variable-looking value that is not the marker
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t?tpl=%24%7Buser.name%7D
--- error_code: 200

=== TEST 10: a JSON body with ordinary content
--- config
    location /t { skel block; skel_max_body 8k; empty_gif; }
--- more_headers
Content-Type: application/json
--- request
POST /t
{"query":"skeleton","marker":"trailhead"}
--- error_code: 405

=== TEST 11: an empty query string
--- config
    location /t { skel block; empty_gif; }
--- request
GET /t
--- error_code: 200

=== TEST 12: an empty body
--- config
    location /t { skel block; skel_max_body 8k; empty_gif; }
--- request
POST /t
--- error_code: 405
