#!/bin/bash

# Dynamic pipeline generator for Bazel tests with "it-test" tag
# This script queries Bazel for all targets tagged with "it-test" and creates individual test jobs

set -euo pipefail

# Function to log to stderr
log() {
    echo "$@" >&2
}

log "--- :bazel: Querying for it-test targets"

# Query Bazel for all targets with the "it-test" tag
IT_TEST_TARGETS=$(bazel query 'attr(tags, "it-test", //tests/...)' 2>/dev/null || {
    log "Error: Failed to query Bazel targets"
    exit 1
})

# Check if we found any targets
if [ -z "$IT_TEST_TARGETS" ]; then
    log "No targets found with 'it-test' tag"
    exit 1
fi

# Count the targets for logging
TARGET_COUNT=$(echo "$IT_TEST_TARGETS" | wc -l | tr -d ' ')
log "Found $TARGET_COUNT targets with 'it-test' tag"

# Begin the pipeline YAML
echo "steps:"

# Add a group step to organize all the test jobs
echo "  - group: \":test_tube: Integration Tests ($TARGET_COUNT tests)\""
echo "    key: \"it-tests\""
echo "    steps:"

# Generate a test step for each target
while IFS= read -r target; do
    # Skip empty lines
    if [ -z "$target" ]; then
        continue
    fi
    
    # Extract a clean name for the step label (remove //tests/ prefix and : separators)
    CLEAN_NAME=$(echo "$target" | sed 's|//tests/||' | sed 's|:|/|')
    
    # Generate the test step with proper YAML escaping
    STEP_KEY=$(echo "$target" | sed 's|[/:]|-|g' | sed 's|^--||' | sed 's|//||g')
    
    cat << EOF
      - label: ":test_tube: $CLEAN_NAME"
        command: |
          echo "--- Running test: $target"
          bazel test "$target" --test_output=errors --test_summary=detailed
        key: "$STEP_KEY"
        timeout_in_minutes: 10
        retry:
          automatic:
            - exit_status: "*"
              limit: 2
        artifact_paths:
          - "bazel-testlogs/**/*"
EOF

done <<< "$IT_TEST_TARGETS"

# Add a final step that waits for all tests and reports summary
cat << 'EOF'

  - wait: ~
    continue_on_failure: true

  - label: ":bar_chart: Test Summary"
    command: |
      echo "--- :white_check_mark: Integration Test Summary"
      echo "All integration tests completed!"
    depends_on:
      - "it-tests"
EOF
