# Pipeline Echo Chunks

This directory contains 40 pipeline chunks, each designed to stay under Buildkite's 500 job upload limit.

## Overview

- **Original Pipeline**: 20,000 total jobs (40 groups × 10 steps × 50 parallelism)
- **Chunking Strategy**: Split into 40 separate pipeline files
- **Jobs per Chunk**: Exactly 500 jobs (1 group × 10 steps × 50 parallelism)
- **Total Chunks**: 40 files

## File Structure

```
pipeline-echo-chunk-01.yml  # Test Group 1  (500 jobs)
pipeline-echo-chunk-02.yml  # Test Group 2  (500 jobs)
pipeline-echo-chunk-03.yml  # Test Group 3  (500 jobs)
...
pipeline-echo-chunk-40.yml  # Test Group 40 (500 jobs)
```

## Usage

### Upload All Chunks
```bash
# From the project root
./.buildkite/upload-all-chunks.sh
```

### Upload Individual Chunks
```bash
# Upload a specific chunk
buildkite-agent pipeline upload .buildkite/chunks/pipeline-echo-chunk-01.yml

# Upload multiple specific chunks
buildkite-agent pipeline upload .buildkite/chunks/pipeline-echo-chunk-{01..05}.yml
```

### Upload Chunks in Batches
```bash
# Upload first 10 chunks
for i in {01..10}; do
  buildkite-agent pipeline upload .buildkite/chunks/pipeline-echo-chunk-$i.yml
done

# Upload chunks 11-20
for i in {11..20}; do
  buildkite-agent pipeline upload .buildkite/chunks/pipeline-echo-chunk-$i.yml
done
```

## Chunk Details

Each chunk contains:
- 1 test group with a unique name (e.g., "Test Group 1", "Test Group 2")
- 10 command steps per group
- 50 parallelism per step
- Total: 500 jobs per chunk

## Benefits of Chunking

1. **Upload Limit Compliance**: Each chunk stays well under the 500 job limit
2. **Parallel Execution**: Multiple chunks can run simultaneously
3. **Granular Control**: Upload only the chunks you need
4. **Error Isolation**: Issues in one chunk don't affect others
5. **Resource Management**: Better distribution of workload

## Monitoring

When all chunks are uploaded and running:
- Total pipeline jobs: 20,000
- Expected parallel execution across all chunks
- Each chunk will show as a separate pipeline in Buildkite UI
