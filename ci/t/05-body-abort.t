use Test::Nginx::Socket 'no_plan';

repeat_each(1);
no_long_string();
run_tests();

__DATA__

=== TEST 1: client disconnects mid-body -- read_client_request_body() itself fails
--- config
    location /t { skel block; skel_max_body 8k; empty_gif; }
--- raw_request eval
"POST /t HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1000\r\nConnection: close\r\n\r\n" . ("A" x 10)
--- shutdown: 1
--- timeout: 3
--- abort
--- error_code eval
''
