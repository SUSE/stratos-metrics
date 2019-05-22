#!/usr/bin/env bash

# 
# Helm Chart Build Script
#
# Allows Helm Chart to be packaged without building images
# 
set -eu

# Set defaults
DOCKER_REGISTRY=docker.io
DOCKER_ORG=splatform
BASE_IMAGE_TAG=opensuse
OFFICIAL_TAG=cap
TAG=$(date -u +"%Y%m%dT%H%M%SZ")
ADD_OFFICIAL_TAG="false"
TAG_LATEST="false"
PUSH="false"
NO_PATCH="false"

while getopts ":ho:r:t:Tcb:C:i:-" opt; do
  case $opt in
    h)
      echo
      echo "To build the Stratos Helm Chart: "
      echo
      echo " ./build-helm.sh -t 1.0.13"
      echo
      exit 0
      ;;
    r)
      DOCKER_REGISTRY="${OPTARG}"
      ;;
    o)
      DOCKER_ORG="${OPTARG}"
      ;;
    t)
      TAG="${OPTARG}"
      ;;
    b)
      BASE_IMAGE_TAG="${OPTARG}"
      ;;
    T)
      TAG="$(git describe $(git rev-list --tags --max-count=1))"
      ;;
    C)
      ADD_OFFICIAL_TAG="true"
      ;;
    i)
      IMAGE_TAG="${OPTARG}"
      ;;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

IMAGE_TAG=${IMAGE_TAG-${TAG}}

if [ "${DOCKER_REGISTRY}" != "docker.io" ]; then
  DOCKER_REPOSITORY="${DOCKER_REGISTRY}\/${DOCKER_ORG}"
else
  DOCKER_REPOSITORY="${DOCKER_ORG}"
fi

echo
echo "REGISTRY: ${DOCKER_REGISTRY}"
echo "ORG: ${DOCKER_ORG}"
echo "FULL DOCKER PATH: ${DOCKER_REPOSITORY}"
echo "TAG: ${TAG}"
echo "IMAGE TAG: ${IMAGE_TAG}"
echo "BASE_IMAGE_TAG: ${BASE_IMAGE_TAG}"
echo "TAG_LATEST: ${TAG_LATEST}"

echo
echo "Starting build of Stratos Metrics Helm Chart"

# Copy values template
__DIRNAME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STRATOS_METRICS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
TMP_DIR=${STRATOS_METRICS_PATH}/tmp
CHART_DIR=${STRATOS_METRICS_PATH}/tmp/metrics
rm -rf ${TMP_DIR}
mkdir -p ${CHART_DIR}

cp ${STRATOS_METRICS_PATH}/*.yaml ${CHART_DIR}
cp -R ${STRATOS_METRICS_PATH}/templates ${CHART_DIR}

pushd ${CHART_DIR} > /dev/null 2>&1
helm dependency build

# Patch chart file
sed -i.bak -e 's/version: [0-9\.]*/version: '"${TAG}"'/g' Chart.yaml

sed -i.bak -e 's/imageTag: [a-z0-9\.-]*/imageTag: '"${IMAGE_TAG}"'/g' values.yaml
sed -i.bak -e 's/dockerOrganization: [a-z]*/dockerOrganization: '"${DOCKER_ORG}"'/g' values.yaml
sed -i.bak -e 's/dockerRepository: [a-z\.]*/dockerRepository: '"${DOCKER_REGISTRY}"'/g' values.yaml
sed -i.bak -e 's/repository: [a-z\.]*/repository: '"${DOCKER_REPOSITORY}"'/g' values.yaml
sed -i.bak -e 's/tag: .*/tag: '"${IMAGE_TAG}"'/g' values.yaml

rm -r *.bak

popd > /dev/null 2>&1

FILENAME_SUFFIX=""
if [ "${ADD_OFFICIAL_TAG}" == "true" ]; then
  FILENAME_SUFFIX = "-${OFFICIAL_TAG}"
fi

pushd ${TMP_DIR} > /dev/null 2>&1
helm package ${CHART_DIR}
CHART=$(ls metrics*.tgz)
popd > /dev/null 2>&1
mv ${TMP_DIR}/${CHART} ./metrics-helm-chart-v${IMAGE_TAG}.tgz
