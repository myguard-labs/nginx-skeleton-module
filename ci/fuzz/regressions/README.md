# Fuzz regressions

Every crash the fuzzer finds gets its reproducer committed here, named for the
bug it triggers. `fuzz/build.sh` + the fuzzing.yml gate replay this directory on
every PR, so a fixed crash can never silently come back.

To replay one by hand:

    bash tools/ci-build.sh nginx 1.31.2
    CC=clang bash fuzz/build.sh
    ./fuzz/fuzz_scan fuzz/regressions/<file>

Empty until the first crash lands. That is the point.
