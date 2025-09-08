#!/bin/bash

# Enable extended globbing for ** patterns (if supported)
shopt -s nullglob 2>/dev/null || true

# Check if file glob pattern is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file_glob_pattern>"
    echo "Example: $0 '*.xml'"
    echo "Example: $0 'bazel-testlogs/**/*.xml'"
    exit 1
fi

FILE_GLOB="$1"

# Use find command to locate files matching the pattern
# Convert glob pattern to find-compatible pattern
if [[ "$FILE_GLOB" == *"**"* ]]; then
    # Handle recursive patterns like bazel-testlogs/**/*.xml
    base_dir=$(echo "$FILE_GLOB" | cut -d'*' -f1)
    file_pattern=$(echo "$FILE_GLOB" | sed 's/.*\*\*\///')
    files=($(find "$base_dir" -name "$file_pattern" -type f 2>/dev/null))
else
    # Handle simple patterns like *.xml
    files=($(find . -maxdepth 1 -name "$FILE_GLOB" -type f 2>/dev/null))
fi

# If find approach didn't work, try direct glob expansion
if [ ${#files[@]} -eq 0 ]; then
    files=($FILE_GLOB)
fi

# Check if any files were found
if [ ${#files[@]} -eq 0 ] || [ ! -f "${files[0]}" ]; then
    echo "Warning: No files found matching pattern '$FILE_GLOB'"
    exit 1
fi

echo "Found ${#files[@]} file(s) matching pattern '$FILE_GLOB'"

# Process each file
for file in "${files[@]}"; do
    # Double-check file exists
    if [ ! -f "$file" ]; then
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