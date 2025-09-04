#!/bin/bash

# Script to upload all pipeline chunks to Buildkite
# Each chunk contains exactly 500 jobs (1 group × 10 steps × 50 parallelism)

set -e

CHUNKS_DIR=".buildkite/chunks"
TOTAL_CHUNKS=40

echo "🚀 Uploading $TOTAL_CHUNKS pipeline chunks to Buildkite..."
echo "Each chunk contains exactly 500 jobs"
echo "Working directory: $(pwd)"
echo ""

# Verify chunks directory exists
if [ ! -d "$CHUNKS_DIR" ]; then
    echo "❌ Error: Chunks directory '$CHUNKS_DIR' not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check if buildkite-agent is available
if ! command -v buildkite-agent &> /dev/null; then
    echo "❌ Error: buildkite-agent command not found"
    echo "Please install the Buildkite agent or run this script in a Buildkite environment"
    exit 1
fi

# Upload each chunk
for i in $(seq -f "%02g" 1 $TOTAL_CHUNKS); do
    chunk_file="$CHUNKS_DIR/pipeline-echo-chunk-$i.yml"
    
    if [ -f "$chunk_file" ]; then
        echo "📤 Uploading chunk $i/40: $chunk_file"
        buildkite-agent pipeline upload "$chunk_file"
        
        # Add a small delay to avoid overwhelming the API
        sleep 0.5
    else
        echo "⚠️  Warning: $chunk_file not found"
    fi
done

echo ""
echo "✅ All chunks uploaded successfully!"
echo "Total jobs across all chunks: $((TOTAL_CHUNKS * 500)) jobs"
echo ""
echo "💡 Tip: You can also upload individual chunks manually:"
echo "   buildkite-agent pipeline upload .buildkite/chunks/pipeline-echo-chunk-01.yml"
