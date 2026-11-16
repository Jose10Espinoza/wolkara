#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/network-health
xcrun clang -fobjc-arc -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined \
    -fno-omit-frame-pointer -Iruntime runtime/NetworkHealth.m tests/test_network_health.m \
    -framework Foundation -o build/network-health/test
build/network-health/test
