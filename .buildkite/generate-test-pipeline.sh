#!/bin/bash

# Dynamic pipeline generator for Bazel tests with "small-it" tag
# This script queries Bazel for all targets tagged with "small-it" and creates individual test jobs

set -euo pipefail

# Function to log to stderr
log() {
    echo "$@" >&2
}

log "--- :bazel: Querying for small-it targets"

# Check if Bazel is available
if ! command -v bazel >/dev/null 2>&1; then
    log "Error: Bazel is not installed or not in PATH"
    exit 1
fi

# Check if we're in a Bazel workspace
if [ ! -f "WORKSPACE" ] && [ ! -f "MODULE.bazel" ]; then
    log "Error: Not in a Bazel workspace (no WORKSPACE or MODULE.bazel file found)"
    exit 1
fi

# Query Bazel for all targets with the "small-it" tag
log "Running: bazel query 'attr(tags, \"small-it\", //tests/...)'"
IT_TEST_TARGETS=$(bazel query 'attr(tags, "small-it", //tests/...)' 2>/dev/null | grep -E '^//tests/' || {
    log "Error: Failed to query Bazel targets"
    log "Bazel query command failed. This might be due to:"
    log "1. Bazel workspace not properly initialized"
    log "2. Missing dependencies"
    log "3. Syntax error in BUILD files"
    log "4. Network issues downloading dependencies"
    exit 1
})

# Check if we found any targets
if [ -z "$IT_TEST_TARGETS" ]; then
    log "No targets found with 'small-it' tag"
    exit 1
fi

# Count the targets for logging
TARGET_COUNT=$(echo "$IT_TEST_TARGETS" | wc -l | tr -d ' ')
TOTAL_JOBS=$((TARGET_COUNT * 200))
log "Found $TARGET_COUNT targets with 'small-it' tag"
log "Generating $TOTAL_JOBS total jobs (200 iterations × $TARGET_COUNT targets)"

# Begin the pipeline YAML
echo "steps:"

# Generate grouped steps by iteration using build matrix
for iteration in $(seq 1 200); do
    log "Generating iteration group $iteration with matrix for all $TARGET_COUNT targets"
    
    cat << EOF
- group: ":test_tube: Iteration $iteration ($TARGET_COUNT tests)"
  key: "iteration-$iteration"
  steps:
    - label: ":test_tube: All Tests (iter-$iteration)"
      command: |
        echo "--- Running test iteration $iteration: {{matrix}}"
        bazel test "{{matrix}}" --test_output=errors --test_summary=detailed
      key: "matrix-tests-iter-$iteration"
      timeout_in_minutes: 10
      agents:
        queue: "test-agent"
      env:
        MY_TEST_ENV: "magic_secret"
        TEST_ITERATION: "$iteration"
      retry:
        automatic:
          - exit_status: "*"
            limit: 2
      artifact_paths:
        - "bazel-testlogs/**/*"
      matrix:
EOF

    # Add all test targets to the matrix for this iteration
    while IFS= read -r target; do
        # Skip empty lines
        if [ -z "$target" ]; then
            continue
        fi
        echo "        - \"$target\""
    done <<< "$IT_TEST_TARGETS"

    echo ""  # Add blank line between iterations
done

# Add a final step that waits for all tests and reports summary
cat << EOF

- wait: ~
  continue_on_failure: true

- label: ":bar_chart: Test Summary ($TOTAL_JOBS jobs completed)"
  command: |
    echo "--- :white_check_mark: Integration Test Summary"
    echo "Total jobs executed: $TOTAL_JOBS"
    echo "All integration tests completed!"
  agents:
    queue: "test-agent"
EOF
