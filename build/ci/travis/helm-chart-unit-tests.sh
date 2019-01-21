#!/bin/bash

set -e

echo "Stratos Metrics Helm Chart Unit Tests"
echo "====================================="

echo "Installing Helm"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

echo "Helm Init (Client)"
helm init --client-only

helm version --client

echo "Install Helm unit test plugin"
helm plugin install https://github.com/cf-stratos/helm-unittest

# Fetch dependencies
helm dependency build

# Since the chart is in the root folder, we need to ensure its in a folder named 'metrics'
mkdir -p ./tmp/metrics
cp *.yaml ./tmp/metrics
cp -R templates/ ./tmp/metrics
cp -R tests/ ./tmp/metrics

# Run unit tests
helm unittest ./tmp/metrics

# Run lint
helm lint ./tmp/metrics

rm -rf ./tmp/metrics