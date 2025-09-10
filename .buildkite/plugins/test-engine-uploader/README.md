# Test Engine Uploader Buildkite Plugin

A Buildkite plugin that uploads JUnit XML test results to Buildkite Test Engine with optional redaction of sensitive data. The plugin runs during the post-command phase to collect and upload test results after your build steps complete.

## Features

- Uploads JUnit XML files to Buildkite Test Engine
- Supports glob patterns to find test result files (including symlinked directories)
- Optional redaction of test names and test output for security
- Configurable upload timeout and file size limits
- Handles multiple files with batch processing
- Comprehensive error handling and reporting

## Requirements

- `curl` command-line tool
- `python3` for XML processing and redaction
- `BUILDKITE_ANALYTICS_TOKEN` environment variable (or custom token variable)

## Configuration

Add the plugin to your pipeline configuration:

```yaml
steps:
  - label: "Run tests"
    command: "bazel test //..."
    plugins:
      - test-engine-uploader:
          file_pattern: "bazel-testlogs/**/*.xml"
          redact: true
```

### Configuration Options

#### `file_pattern` (required)

Glob pattern to match JUnit XML files. Examples:
- `"bazel-testlogs/**/*.xml"` - All XML files in bazel test logs
- `"test-results/*.xml"` - XML files in test-results directory
- `"**/TEST-*.xml"` - Files matching TEST-*.xml pattern anywhere

#### `redact` (optional)

Whether to redact all sensitive data in the XML files. Defaults to `false`.

When enabled, redacts:
- **Test names**: `testcase/@name`, `testcase/@classname`, `testsuite/@name`, `testsuites/@name` with `[REDACTED]_<last_5_chars>`
- **Test output**: `<failure>`, `<error>`, `<system-out>`, `<system-err>`, `<skipped>` elements and their `@message` attributes

#### `analytics_token_env` (optional)

Environment variable name containing the Buildkite Analytics token. Defaults to `"BUILDKITE_ANALYTICS_TOKEN"`.

#### `upload_timeout` (optional)

Timeout in seconds for each file upload. Defaults to `30`.

#### `max_file_size` (optional)

Maximum file size in MB to upload. Files larger than this will be skipped. Defaults to `10`.

#### `upload_parallelism` (optional)

Number of parallel upload jobs. Defaults to `5`.

## Usage Examples

### Basic Usage

```yaml
steps:
  - label: "Run tests and upload results"
    command: "npm test"
    plugins:
      - test-engine-uploader:
          file_pattern: "test-results/**/*.xml"
```

### With Redaction

```yaml
steps:
  - label: "Run secure tests"
    command: "bazel test //..."
    plugins:
      - test-engine-uploader:
          file_pattern: "bazel-testlogs/**/*.xml"
          redact: true
```

### Custom Configuration

```yaml
steps:
  - label: "Run tests with custom settings"
    command: "gradle test"
    plugins:
      - test-engine-uploader:
          file_pattern: "build/test-results/**/*.xml"
          analytics_token_env: "CUSTOM_ANALYTICS_TOKEN"
          upload_timeout: 60
          max_file_size: 20
          upload_parallelism: 8
```

### Multiple Test Types

```yaml
steps:
  - label: "Run all tests"
    command: |
      npm test
      bazel test //...
    plugins:
      - test-engine-uploader:
          file_pattern: "{test-results,bazel-testlogs}/**/*.xml"
          redact: true
```

## How It Works

1. The plugin runs during the post-command phase after your build/test commands complete
2. It searches for XML files using both standard and symlink-aware approaches to handle all directory structures
3. Files are divided into batches for parallel processing based on `upload_parallelism` setting
4. For each batch of files:
   - Applies redaction if `redact: true` (creates processed copies with all sensitive data redacted)
   - Checks file size against the limit
   - Uploads files to Buildkite Test Engine in parallel
5. Provides a summary of upload results with success/failure counts

## Redaction Details

### Test Name Redaction
When `redact: true`, the plugin keeps the last 5 characters of test names for identification:
```xml
<!-- Before -->
<testcase name="UDFServerTest_TestCreatetUdfClientAfterOom_Test" classname="com.snowflake.UDFServerTest" />
<testsuite name="UDFServerTest_TestCreatetUdfClientAfterOom_Test" />

<!-- After -->
<testcase name="[REDACTED]__Test" classname="[REDACTED]_rTest" />
<testsuite name="[REDACTED]__Test" />
```

For names 5 characters or shorter:
```xml
<!-- Before -->
<testcase name="shortTest" classname="TestClass" />

<!-- After -->
<testcase name="[REDACTED]_shortTest" classname="[REDACTED]_TestClass" />
```

### Test Output Redaction
When `redact: true`:
```xml
<!-- Before -->
<failure message="Expected user123 but got user456">
  Stack trace with sensitive data...
</failure>

<!-- After -->
<failure message="[REDACTED]">
  [REDACTED]
</failure>
```

## Environment Variables

The plugin automatically includes standard Buildkite environment variables in the upload:

- `BUILDKITE_BUILD_ID`
- `BUILDKITE_BUILD_NUMBER` 
- `BUILDKITE_JOB_ID`
- `BUILDKITE_BRANCH`
- `BUILDKITE_COMMIT`
- `BUILDKITE_MESSAGE`
- `BUILDKITE_BUILD_URL`

## Error Handling

The plugin handles various error conditions gracefully:

- **Missing analytics token**: Fails with clear error message
- **No matching files**: Continues with warning
- **File size exceeded**: Skips file with warning
- **Upload failures**: Reports but continues with other files
- **XML processing errors**: Reports but continues with original file

## Symlink Support

The plugin properly handles symlinked directories (common with Bazel's `bazel-testlogs` symlink) by using `find` with appropriate options.

## Security Considerations

- Analytics token should be stored securely in Buildkite environment variables
- Use redaction options when test names or output contain sensitive information
- Processed files are stored in temporary directories and cleaned up automatically
- Original test files are never modified

## Troubleshooting

### No files found
- Verify the glob pattern matches your test output structure
- Check that tests are actually generating XML output
- Ensure the pattern accounts for your directory structure

### Upload failures
- Verify `BUILDKITE_ANALYTICS_TOKEN` is set correctly
- Check network connectivity to `analytics-api.buildkite.com`
- Increase `upload_timeout` for large files or slow connections

### XML processing errors
- Ensure `python3` is installed on your build agents
- Verify XML files are valid JUnit format
- Check file permissions and accessibility

## Development

The plugin consists of:
- `plugin.yml`: Plugin configuration and schema
- `hooks/post-command`: Main upload script with parallel processing and batch management
- `redact_xml.py`: Simplified Python script that redacts all sensitive data from JUnit XML files

## License

This plugin is part of the Snowflake internal tooling.
