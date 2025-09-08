#!/bin/bash

# Check if file glob pattern is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file_glob_pattern>"
    echo "Example: $0 '*.xml'"
    echo "Example: $0 'test-results/**/*.xml'"
    exit 1
fi

FILE_GLOB="$1"

# Find all files matching the glob pattern
for file in $FILE_GLOB; do
    # Check if file exists (in case glob doesn't match anything)
    if [ ! -f "$file" ]; then
        echo "Warning: No files found matching pattern '$FILE_GLOB'"
        continue
    fi
    
    echo "Uploading test results from: $file"
    
    curl -X POST \
      -H "Authorization: Token token=$BUILDKITE_ANALYTICS_TOKEN" \
      -F "format=junit" \
      -F "data=@$file" \
      -F "run_env[CI]=buildkite" \
      -F "run_env[key]=$BUILDKITE_BUILD_ID" \
      -F "run_env[number]=$BUILDKITE_BUILD_NUMBER" \
      -F "run_env[job_id]=$BUILDKITE_JOB_ID" \
      -F "run_env[branch]=$BUILDKITE_BRANCH" \
      -F "run_env[commit_sha]=$BUILDKITE_COMMIT" \
      -F "run_env[message]=$BUILDKITE_MESSAGE" \
      -F "run_env[url]=$BUILDKITE_BUILD_URL" \
      https://analytics-api.buildkite.com/v1/uploads
    
    # Check curl exit status
    if [ $? -eq 0 ]; then
        echo "✓ Successfully uploaded: $file"
    else
        echo "✗ Failed to upload: $file"
    fi
    
    echo "---"
done