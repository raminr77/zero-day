#!/usr/bin/env bash
# Shared test setup. Sourced by each .bats file.

# Resolve the repo root from the tests directory.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
export REPO_ROOT

# Load the library under test. ui.sh is sourced too because common.sh callers
# may reference it, but the pure helpers we test don't print UI.
load_libs() {
  # NO_COLOR keeps assertions free of escape codes.
  export NO_COLOR=1
  # shellcheck source=../lib/ui.sh
  source "$REPO_ROOT/lib/ui.sh"
  # shellcheck source=../lib/common.sh
  source "$REPO_ROOT/lib/common.sh"
}

# Create an isolated fake HOME for filesystem tests; echo its path.
make_tmp_home() {
  local d
  d="$(mktemp -d)"
  echo "$d"
}
