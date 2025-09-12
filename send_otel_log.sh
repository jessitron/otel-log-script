#!/bin/bash

# Default values
ENDPOINT="http://localhost:4318/v1/logs"
TIMESTAMP=$(date +%s%N)
SERVICE_NAME="otel-log-script"

usage() {
    echo "Usage: $0 <log_body> [name=value ...]"
    echo "       $0 --endpoint <url> <log_body> [name=value ...]"
    echo ""
    echo "Examples:"
    echo "  $0 'Hello world'"
    echo "  $0 'User logged in' user_id=123 action=login"
    echo "  $0 --endpoint http://jaeger:4318/v1/logs 'Error occurred' severity=error"
    exit 1
}

# Parse arguments
if [[ $# -lt 1 ]]; then
    usage
fi

# Check for endpoint override
if [[ "$1" == "--endpoint" ]]; then
    if [[ $# -lt 3 ]]; then
        usage
    fi
    ENDPOINT="$2"
    shift 2
fi

LOG_BODY="$1"
shift

# Parse attributes
ATTRIBUTES=""
for arg in "$@"; do
    if [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        if [[ -n "$ATTRIBUTES" ]]; then
            ATTRIBUTES="$ATTRIBUTES,"
        fi
        ATTRIBUTES="$ATTRIBUTES\"$name\": {\"stringValue\": \"$value\"}"
    else
        echo "Warning: Invalid attribute format '$arg'. Expected name=value" >&2
    fi
done

# Build JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "$SERVICE_NAME"
            }
          }
        ]
      },
      "scopeLogs": [
        {
          "scope": {
            "name": "otel-log-script",
            "version": "1.0.0"
          },
          "logRecords": [
            {
              "timeUnixNano": "$TIMESTAMP",
              "body": {
                "stringValue": "$LOG_BODY"
              },
              "attributes": [
                $(if [[ -n "$ATTRIBUTES" ]]; then echo "{$ATTRIBUTES}"; fi)
              ],
              "severityText": "INFO"
            }
          ]
        }
      ]
    }
  ]
}
EOF
)

# Send the log
response=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | head -n -1)

if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "Log sent successfully: '$LOG_BODY'"
    if [[ -n "$ATTRIBUTES" ]]; then
        echo "Attributes: $@"
    fi
else
    echo "Error sending log (HTTP $http_code): $response_body" >&2
    exit 1
fi