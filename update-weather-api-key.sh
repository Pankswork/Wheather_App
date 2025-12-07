#!/bin/bash

# Script to add/update Weather API key in Kubernetes deployment

set -e

NAMESPACE="${K8S_NAMESPACE:-pythonapp-dev}"
SECRET_NAME="weather-api-key"

if [ -z "$1" ]; then
    read -sp "Enter your Weather API key: " WEATHER_API_KEY
    echo
else
    WEATHER_API_KEY="$1"
fi

echo "Creating/updating Weather API key secret..."

kubectl create secret generic "$SECRET_NAME" \
    --from-literal=WEATHER_API_KEY="$WEATHER_API_KEY" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Updating deployment to use Weather API key..."

# Get current deployment and patch it
kubectl patch deployment pythonapp-app -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "WEATHER_API_KEY",
      "valueFrom": {
        "secretKeyRef": {
          "name": "'"$SECRET_NAME"'",
          "key": "WEATHER_API_KEY"
        }
      }
    }
  }
]' || {
    echo "Note: If deployment doesn't exist yet, it will be created by Terraform."
    echo "You can manually add the env variable after deployment."
}

echo "✅ Weather API key configured!"
echo "The deployment will restart with the new API key."





