#!/bin/bash

set -e

# Check required environment variable
if [ -z "$OTEL_SERVICE_NAME" ]; then
    echo "Error: OTEL_SERVICE_NAME environment variable is required"
    exit 1
fi

# Set defaults for optional environment variables
OTEL_EXPORTER_OTLP_HEADERS=${OTEL_EXPORTER_OTLP_HEADERS:-""}
OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-"http://localhost:4317"}

# Extract Honeycomb API key from headers
if [ -n "$OTEL_EXPORTER_OTLP_HEADERS" ]; then
    HONEYCOMB_API_KEY=$(echo "$OTEL_EXPORTER_OTLP_HEADERS" | grep -o 'x-honeycomb-team=[^,]*' | cut -d'=' -f2)
    HONEYCOMB_DATASET=$(echo "$OTEL_EXPORTER_OTLP_HEADERS" | grep -o 'x-honeycomb-dataset=[^,]*' | cut -d'=' -f2 || echo "logs")
else
    echo "Warning: OTEL_EXPORTER_OTLP_HEADERS not set, using localhost endpoint"
    HONEYCOMB_API_KEY=""
    HONEYCOMB_DATASET="logs"
fi

# Read JSON from stdin
JSON_INPUT=$(cat)

# Generate timestamp in nanoseconds
TIMESTAMP_NANOS=$(date +%s%N)

# Function to convert JSON to OTLP attributes
json_to_attributes() {
    local json="$1"
    local attributes=""
    
    # Create a temporary file to store the parsed data
    local tempfile=$(mktemp)
    echo "$json" | jq -r 'to_entries[] | [.key, (.value | if type == "object" or type == "array" then tojson else tostring end), (.value | type)] | @tsv' > "$tempfile"
    
    while IFS=$'\t' read -r key value type; do
        if [ -n "$key" ]; then
            if [ -n "$attributes" ]; then
                attributes="$attributes,"
            fi
            
            # Escape quotes in the value for JSON
            value_escaped=$(echo "$value" | sed 's/"/\\"/g')
            
            # Determine value type and format accordingly
            case "$type" in
                "string")
                    attributes="$attributes{\"key\":\"$key\",\"value\":{\"stringValue\":\"$value_escaped\"}}"
                    ;;
                "number")
                    if [[ "$value" == *.* ]]; then
                        attributes="$attributes{\"key\":\"$key\",\"value\":{\"doubleValue\":$value}}"
                    else
                        attributes="$attributes{\"key\":\"$key\",\"value\":{\"intValue\":$value}}"
                    fi
                    ;;
                "boolean")
                    attributes="$attributes{\"key\":\"$key\",\"value\":{\"boolValue\":$value}}"
                    ;;
                "null")
                    attributes="$attributes{\"key\":\"$key\",\"value\":{\"stringValue\":\"null\"}}"
                    ;;
                *)
                    # For objects and arrays, convert to JSON string
                    attributes="$attributes{\"key\":\"$key\",\"value\":{\"stringValue\":\"$value_escaped\"}}"
                    ;;
            esac
        fi
    done < "$tempfile"
    
    rm "$tempfile"
    echo "$attributes"
}

# Convert input JSON to OTLP attributes
DYNAMIC_ATTRIBUTES=$(json_to_attributes "$JSON_INPUT")

# Create OTLP log payload with dynamic attributes
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
            "name": "stdin-json-processor",
            "version": "1.0.0"
          },
          "logRecords": [
            {
              "timeUnixNano": "'$TIMESTAMP_NANOS'",
              "severityNumber": 9,
              "severityText": "INFO",
              "body": {
                "stringValue": "Log with attributes from stdin JSON at '"$(date)"'"
              },
              "attributes": ['$DYNAMIC_ATTRIBUTES']
            }
          ]
        }
      ]
    }
  ]
}'

echo "Sending OTLP log..."
echo "Service: $OTEL_SERVICE_NAME"
echo "Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "Headers: $OTEL_EXPORTER_OTLP_HEADERS"
echo "Attributes: $DYNAMIC_ATTRIBUTES"

# Determine endpoint and headers based on configuration
if [[ "$OTEL_EXPORTER_OTLP_ENDPOINT" == *"honeycomb"* ]] && [ -n "$HONEYCOMB_API_KEY" ]; then
    # Send to Honeycomb using their logs API
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "x-honeycomb-team: $HONEYCOMB_API_KEY" \
      -H "x-honeycomb-dataset: $HONEYCOMB_DATASET" \
      -d "$OTLP_LOG_PAYLOAD" \
      "https://api.honeycomb.io/v1/logs" \
      --fail --silent --show-error
else
    # Send to OTLP endpoint (default or custom)
    curl -X POST \
      -H "Content-Type: application/json" \
      ${OTEL_EXPORTER_OTLP_HEADERS:+-H "$OTEL_EXPORTER_OTLP_HEADERS"} \
      -d "$OTLP_LOG_PAYLOAD" \
      "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/logs" \
      --fail --silent --show-error
fi

echo "✅ Log sent successfully!"
echo "Check your observability backend for the log entry."