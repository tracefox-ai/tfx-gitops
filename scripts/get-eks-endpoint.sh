#!/bin/bash
# Script to get EKS cluster endpoint for ArgoCD configuration

set -e

# Method 1: Using AWS CLI (recommended)
if command -v aws &> /dev/null; then
  echo "Getting EKS cluster endpoint using AWS CLI..."
  echo ""
  echo "Available clusters:"
  aws eks list-clusters --output table
  echo ""
  read -p "Enter your EKS cluster name: " CLUSTER_NAME
  echo ""
  ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.endpoint' --output text 2>/dev/null)
  if [ -n "$ENDPOINT" ]; then
    echo "Your EKS cluster endpoint is:"
    echo "$ENDPOINT"
    echo ""
    echo "Update argocd/bootstrap/root.yaml with:"
    echo "  server: $ENDPOINT"
  else
    echo "Error: Could not retrieve cluster endpoint. Check your AWS credentials and cluster name."
    exit 1
  fi
# Method 2: Using kubectl
elif command -v kubectl &> /dev/null; then
  echo "Getting cluster endpoint using kubectl..."
  ENDPOINT=$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '{print $NF}' | sed 's/https:\/\///')
  if [ -n "$ENDPOINT" ]; then
    echo "Your cluster endpoint is:"
    echo "https://$ENDPOINT"
    echo ""
    echo "Update argocd/bootstrap/root.yaml with:"
    echo "  server: https://$ENDPOINT"
  else
    echo "Error: Could not retrieve cluster endpoint from kubectl."
    exit 1
  fi
else
  echo "Error: Neither AWS CLI nor kubectl found. Please install one of them."
  exit 1
fi
