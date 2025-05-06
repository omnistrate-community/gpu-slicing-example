#!/bin/bash

# create_and_monitor.sh
# This script automates the process of creating a GPU instance using Omnistrate,
# monitoring its status, and testing the service endpoint.
# It handles cleanup of the instance upon exit

# NOTES: this script is not ready for use yet, it is a work in progress

# Service configuration
SERVICE_NAME="gpu-slicing-example"
SERVICE_PLAN="gpu-slicing-example"
ENVIRONMENT="Dev"
CLOUD_PROVIDER="aws"
REGION="ap-south-1"

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ ! -z "$instance_id" ]; then
        echo "Cleaning up: Deleting instance $instance_id..."
        omnistrate-ctl instance delete "$instance_id" --yes || echo "Failed to delete instance"
    fi
    exit $exit_code
}

# Set up trap for cleanup on script exit
trap cleanup EXIT

# Check if .env file exists
if [ ! -f .env ]; then
    echo "No .env file found. Creating one..."
    echo "Please enter your Omnistrate email:"
    read email
    echo "OMNISTRATE_EMAIL=$email" > .env
    echo "Please enter your Omnistrate password:"
    read -s password
    echo "$password" > .omnistrate.password
fi

# Load environment variables from .env file
set -a
source .env
set +a

echo "Logging into Omnistrate..."
cat ./.omnistrate.password | omnistrate-ctl login --email "$OMNISTRATE_EMAIL" --password-stdin

echo "Creating new instance..."
start_time=$(date +%s)
create_output=$(omnistrate-ctl instance create --environment "$ENVIRONMENT" --cloud-provider "$CLOUD_PROVIDER" --region "$REGION" --plan "$SERVICE_PLAN" --service "$SERVICE_NAME" --resource gpuinfo --output json)
instance_id=$(echo "$create_output" | jq -r '.instance_id')

if [ -z "$instance_id" ] || [ "$instance_id" = "null" ]; then
    echo "Failed to get instance ID from create output:"
    echo "$create_output"
    exit 1
fi

echo "Instance ID: $instance_id"
echo "Waiting for instance to be created..."
sleep 1

while true; do
    # Get instance status directly
    instance_json=$(omnistrate-ctl instance describe "$instance_id" --output json)

    if [ -z "$instance_json" ] || [ "$instance_json" = "[]" ]; then
        echo "Instance not found. Waiting..."
        exit 1
    fi

    echo "Instance JSON: $instance_json"

    status=$(echo "$instance_json" | jq -r '.status // "unknown"')
    
    # Check for cluster endpoint and ports in detailedNetworkTopology with null safety
    cluster_endpoint=$(echo "$instance_json" | jq -r '
        if .consumptionResourceInstanceResult != null and 
           .consumptionResourceInstanceResult.detailedNetworkTopology != null then
            .consumptionResourceInstanceResult.detailedNetworkTopology 
            | to_entries[] 
            | select(.value.main == true) 
            | .value.clusterEndpoint 
        else 
            "null"
        end')
    
    cluster_ports=$(echo "$instance_json" | jq -r '
        if .consumptionResourceInstanceResult != null and 
           .consumptionResourceInstanceResult.detailedNetworkTopology != null then
            .consumptionResourceInstanceResult.detailedNetworkTopology 
            | to_entries[] 
            | select(.value.main == true) 
            | .value.clusterPorts[]
        else 
            "null"
        end' 2>/dev/null)
    
    if [ ! -z "$cluster_endpoint" ] && [ "$cluster_endpoint" != "null" ] && [ ! -z "$cluster_ports" ] && [ "$cluster_ports" != "null" ]; then
        echo "Cluster Endpoint: $cluster_endpoint"
        echo "Cluster Ports: $cluster_ports"
        break
    fi

    echo "Waiting for cluster endpoint and ports to be available..."
    sleep 1
done

echo "Testing endpoint connectivity..."
for port in $cluster_ports; do
    endpoint_url="http://${cluster_endpoint}:${port}"
    echo "Trying endpoint: $endpoint_url"
    
    while true; do
        if curl -s "$endpoint_url" > /dev/null; then
            echo "Service is responding on port $port!"
            total_time=$(($(date +%s) - start_time))
            echo "GPU information from the service:"
            curl -s "$endpoint_url" | jq '.'
            echo "Total time from creation to first response: ${total_time} seconds"
            exit 0
        else
            echo "Service not responding on port $port yet... waiting"
            sleep 1
        fi
    done
done