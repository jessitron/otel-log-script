# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OTLP (OpenTelemetry Protocol) log script designed to send observability data to Honeycomb. It's primarily used with Claude Code hooks to automatically send telemetry when Claude performs actions.

## Key Components

- **send_otlp_log.sh**: Main bash script that converts JSON input to OTLP format and sends logs to configured endpoint
- **.env**: Environment configuration for OTEL settings and Honeycomb API endpoint
- **sample-input.json**: Example input showing the hook event data structure from Claude Code
- **.mcp.json**: MCP server configuration for Honeycomb integration

## Common Commands

```bash
# Test the script with sample data
source .env && ./send_otlp_log.sh < sample-input.json

# Run the script with custom JSON input
echo '{"key": "value"}' | source .env && ./send_otlp_log.sh

# Check environment variables are set correctly
source .env && echo "Service: $OTEL_SERVICE_NAME" && echo "Headers: $OTEL_EXPORTER_OTLP_HEADERS"
```

## Architecture

The script follows this flow:
1. Validates `OTEL_SERVICE_NAME` environment variable
2. Reads JSON from stdin
3. Converts all JSON fields to OTLP attributes with "hook." prefix
4. Creates properly formatted OTLP log payload with resource attributes (service.name, service.version, claude.project_dir)
5. Sends via curl to configured OTLP endpoint

## Environment Setup

The `.env` file must be sourced before running the script. It depends on `CLAUDE_CODE_OUTPUT_HONEYCOMB_API_KEY` being set externally (typically by Claude Code hooks system).

## Hook Integration

This script is designed to work with Claude Code's hook system, automatically processing hook event data that includes session_id, transcript_path, cwd, permission_mode, hook_event_name, tool_name, and tool_input.