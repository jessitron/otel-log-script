#!/bin/bash

set -e

# Use existing Claude Code environment variables
if [ -n "$OTEL_EXPORTER_OTLP_HEADERS" ]; then
    HONEYCOMB_API_KEY=$(echo "$OTEL_EXPORTER_OTLP_HEADERS" | grep -o 'x-honeycomb-team=[^,]*' | cut -d'=' -f2)
    HONEYCOMB_DATASET=$(echo "$OTEL_EXPORTER_OTLP_HEADERS" | grep -o 'x-honeycomb-dataset=[^,]*' | cut -d'=' -f2 || echo "claude-code")
else
    echo "Error: OTEL_EXPORTER_OTLP_HEADERS environment variable is not set"
    exit 1
fi

if [ -z "$HONEYCOMB_API_KEY" ]; then
    echo "Error: Could not extract Honeycomb API key from OTEL_EXPORTER_OTLP_HEADERS"
    exit 1
fi

TIMESTAMP_NANOS=$(date +%s%N)

OTLP_LOG_PAYLOAD='{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "'$OTEL_SERVICE_NAME'"
            }
          },
          {
            "key": "service.version",
            "value": {
              "stringValue": "1.0.0"
            }
          }
        ]
      },
      "scopeLogs": [
        {
          "scope": {
            "name": "curl-test",
            "version": "1.0.0"
          },
          "logRecords": [
            {
              "timeUnixNano": "'$TIMESTAMP_NANOS'",
              "severityNumber": 9,
              "severityText": "INFO",
              "body": {
                "stringValue": "Test log message sent via curl from shell script at $(date)"
              },
              "attributes": [
                {
                  "key": "log.source",
                  "value": {
                    "stringValue": "shell-script"
                  }
                },
                {
                  "key": "test.id",
                  "value": {
                    "stringValue": "otlp-curl-test-'$(date +%s)'"
                  }
                },
                {
                  "key": "environment",
                  "value": {
                    "stringValue": "local-test"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}'

echo "Sending OTLP log to Honeycomb..."
echo "Service: $OTEL_SERVICE_NAME"
echo "Dataset: $HONEYCOMB_DATASET"
echo "Endpoint: https://api.honeycomb.io"
echo "Timestamp: $TIMESTAMP_NANOS"

curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-honeycomb-team: $HONEYCOMB_API_KEY" \
  -H "x-honeycomb-dataset: $HONEYCOMB_DATASET" \
  -d "$OTLP_LOG_PAYLOAD" \
  "https://api.honeycomb.io/v1/logs" \
  -v

echo -e "\n✅ Log sent successfully!"
echo "Check your Honeycomb dashboard for the log entry."