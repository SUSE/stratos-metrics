#!/usr/bin/env bash

__DIRNAME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
METRICS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

VERSION=1.1.0-nwm

GIT_HASH=$(git rev-parse --short HEAD)
TAG="${VERSION}-g${GIT_HASH}"
echo "${TAG}"

pushd ${METRICS_PATH}/build
./build.sh -t ${VERSION} -o nwmac -p
if [ $? -ne 0 ]; then
  popd > /dev/null
  echo "Failed to build images"
  exit 1
fi

helm delete my-metrics --purge
kubectl delete namespace metrics

helm install ./metrics-helm-chart-v${TAG}.tgz --namespace metrics --name my-metrics -f ./test/test.values.yaml 
if [ $? -ne 0 ]; then
  echo "Failed to install helm chart"
  exit 1
fi

popd > /dev/null

kubectl get pods --all-namespaces

sleep 10

kubectl get pods --all-namespaces

