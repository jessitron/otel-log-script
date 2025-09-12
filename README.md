# OTLP Log Script for Claude Hooks

This script sends OpenTelemetry Protocol (OTLP) logs and is designed to be used with Claude Code hooks. It reads JSON data from stdin and converts it to OTLP format before sending it to a configured endpoint.

## Setup

### Environment Variables

Create a `.env` file with the following required variables:

```bash
# Required: Service name for the logs
export OTEL_SERVICE_NAME="claude-code"

# Required: Headers for authentication (uses CLAUDE_CODE_OUTPUT_HONEYCOMB_API_KEY)
export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$CLAUDE_CODE_OUTPUT_HONEYCOMB_API_KEY"

# Required: OTLP endpoint URL
export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io:443"
```

**Note:** The `CLAUDE_CODE_OUTPUT_HONEYCOMB_API_KEY` environment variable should be set before sourcing the `.env` file.

### Dependencies

- `bash`
- `curl`
- `jq` (for JSON parsing)

## Usage

### Basic Usage

```bash
# Source environment variables
source .env

# Send JSON data via stdin
echo '{"key": "value"}' | ./send_otlp_log.sh

# Or from a file
./send_otlp_log.sh < sample-input.json
```

### Claude Code Hooks Integration

This script is designed to work with Claude Code hooks. The hook system will automatically:

1. Set the `CLAUDE_CODE_OUTPUT_HONEYCOMB_API_KEY` environment variable
2. Source the `.env` file 
3. Pipe hook event data (JSON) to this script

Example hook event data structure:
```json
{
  "session_id": "a72498ca-f794-4cc1-967e-403fe318832b",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "acceptEdits",
  "hook_event_name": "PreToolUse",
  "tool_name": "Read",
  "tool_input": { "file_path": "/path/to/file.json" }
}
```

## What It Does

1. **Validates Environment**: Checks that `OTEL_SERVICE_NAME` is set
2. **Reads JSON**: Accepts JSON data from stdin
3. **Converts to OTLP**: Transforms the input JSON into OTLP log format with:
   - Dynamic attributes from all JSON fields
   - Proper type handling (string, number, boolean, null, object/array)
   - Timestamp in nanoseconds
   - Service metadata (name, version)
4. **Sends Log**: POSTs the OTLP payload to the configured endpoint

## Output Format

The script creates OTLP logs with:
- **Resource attributes**: `service.name`, `service.version`
- **Scope**: `stdin-json-processor` v1.0.0
- **Log record**: INFO level with "Claude hook" message
- **Dynamic attributes**: All fields from input JSON converted to proper OTLP attribute format

## Error Handling

- Exits with error if `OTEL_SERVICE_NAME` is not set
- Uses `curl --fail --show-error` for HTTP error reporting
- Properly escapes JSON values to prevent injection