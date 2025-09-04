#!/bin/bash

# Dynamic pipeline generator for Bazel tests with "it-test" tag
# This script queries Bazel for all targets tagged with "it-test" and creates individual test jobs

set -euo pipefail

# Function to log to stderr
log() {
    echo "$@" >&2
}

log "--- :bazel: Querying for it-test targets"

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

# Query Bazel for all targets with the "it-test" tag
log "Running: bazel query 'attr(tags, \"it-test\", //tests/...)'"
IT_TEST_TARGETS=$(bazel query 'attr(tags, "it-test", //tests/...)' 2>/dev/null | grep -E '^//tests/' || {
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
    log "No targets found with 'it-test' tag"
    exit 1
fi

# Count the targets for logging
TARGET_COUNT=$(echo "$IT_TEST_TARGETS" | wc -l | tr -d ' ')
TOTAL_JOBS=$((TARGET_COUNT * 650))
log "Found $TARGET_COUNT targets with 'it-test' tag"
log "Generating $TOTAL_JOBS total jobs (650 iterations × $TARGET_COUNT targets)"

# Begin the pipeline YAML
echo "steps:"

# Add a group step to organize all the test jobs
echo "  - group: \":test_tube: Load Test - $TOTAL_JOBS Jobs ($TARGET_COUNT targets × 650 iterations)\""
echo "    key: \"it-tests\""
echo "    steps:"

# Generate a test step for each target with 650 iterations for load testing
while IFS= read -r target; do
    # Skip empty lines
    if [ -z "$target" ]; then
        continue
    fi
    
    # Extract a clean name for the step label (remove //tests/ prefix and : separators)
    CLEAN_NAME=$(echo "$target" | sed 's|//tests/||' | sed 's|:|/|')
    
    # Generate 650 iterations of each test for load testing
    for iteration in $(seq 1 650); do
        # Generate the test step with proper YAML escaping and iteration suffix
        STEP_KEY=$(echo "$target" | sed 's|[/:]|-|g' | sed 's|^--||' | sed 's|//||g')-iter-$iteration
        
        # Log the job name being generated
        log "Generating job: $CLEAN_NAME (iter-$iteration) with key: $STEP_KEY"
        
        cat << EOF
      - label: ":test_tube: $CLEAN_NAME (iter-$iteration)"
        command: |
          echo "--- Running test iteration $iteration: $target"
          bazel test "$target" --test_output=errors --test_summary=detailed
        key: "$STEP_KEY"
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
EOF
    done

done <<< "$IT_TEST_TARGETS"

# Add a final step that waits for all tests and reports summary
cat << 'EOF'

  - wait: ~
    continue_on_failure: true

  - label: ":bar_chart: Test Summary"
    command: |
      echo "--- :white_check_mark: Integration Test Summary"
      echo "All integration tests completed!"
    agents:
      queue: "test-agent"
    depends_on:
      - "it-tests"
EOF
