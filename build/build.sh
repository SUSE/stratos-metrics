#!/usr/bin/env bash

# 
# Image Build script for Stratos Metrics
# 
set -eu

# Set defaults
PROD_RELEASE=false
DOCKER_REGISTRY=docker.io
DOCKER_ORG=splatform
BASE_IMAGE_TAG=opensuse
OFFICIAL_TAG=cap
TAG=$(date -u +"%Y%m%dT%H%M%SZ")
ADD_OFFICIAL_TAG="false"
TAG_LATEST="false"
PUSH="false"
NO_PATCH="false"

while getopts ":ho:r:t:Tcplub:Ou:" opt; do
  case $opt in
    h)
      echo
      echo "--- To build images of Stratos Metrics: "
      echo
      echo " ./build.sh -t 1.0.13"
      echo
      echo "-p Push images to repository"
      echo "-l Tag image as latest"
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
    u)
      NO_PATCH="true"
      ;;
    T)
      TAG="$(git describe $(git rev-list --tags --max-count=1))"
      RELEASE_TAG="$(git describe $(git rev-list --tags --max-count=1))"
      ;;
    c)
      CONCOURSE_BUILD="true"
      ;;
    O)
      ADD_OFFICIAL_TAG="true"
      ;;
    l)
      TAG_LATEST="true"
      ;;
    p)
      PUSH="true"
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

echo
echo "PRODUCTION BUILD/RELEASE: ${PROD_RELEASE}"
echo "REGISTRY: ${DOCKER_REGISTRY}"
echo "ORG: ${DOCKER_ORG}"
echo "TAG: ${TAG}"
echo "BASE_IMAGE_TAG: ${BASE_IMAGE_TAG}"
echo "PUSH IMAGES: ${PUSH}"
echo "TAG_LATEST: ${TAG_LATEST}"

echo
echo "Starting build of Stratos Metics images"

echo ${NO_PATCH}

# Copy values template
__DIRNAME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STRATOS_METRICS_PATH=${__DIRNAME}/..

# Proxy support
BUILD_ARGS=""
RUN_ARGS=""
if [ -n "${http_proxy:-}" -o -n "${HTTP_PROXY:-}" ]; then
  BUILD_ARGS="${BUILD_ARGS} --build-arg http_proxy=${http_proxy:-${HTTP_PROXY}}"
  RUN_ARGS="${RUN_ARGS} -e http_proxy=${http_proxy:-${HTTP_PROXY}}"
fi
if [ -n "${https_proxy:-}" -o -n "${HTTPS_PROXY:-}" ]; then
  BUILD_ARGS="${BUILD_ARGS} --build-arg https_proxy=${https_proxy:-${HTTPS_PROXY}}"
  RUN_ARGS="${RUN_ARGS} -e https_proxy=${https_proxy:-${HTTPS_PROXY}}"
fi

# Trim leading/trailing whitespace
BUILD_ARGS="$(echo -e "${BUILD_ARGS}" | sed -r -e 's@^[[:space:]]*@@' -e 's@[[:space:]]*$@@')"
RUN_ARGS="$(echo -e "${RUN_ARGS}" | sed -r -e 's@^[[:space:]]*@@' -e 's@[[:space:]]*$@@')"

if [ -n "${BUILD_ARGS}" ]; then
  echo "Web Proxy detected from environment. Running Docker with:"
  echo -e "- BUILD_ARGS:\t'${BUILD_ARGS}'"
  echo -e "- RUN_ARGS:\t'${RUN_ARGS}'"
fi

function buildAndPublishImage {
  NAME=${1}
  DOCKER_FILE=${2}
  FOLDER=${3}
  TARGET=${4:-none}

  if [ ! -d "${FOLDER}" ]; then
    echo "Project ${FOLDER} hasn't been checked out";
    exit 1
  fi

  echo "-- Build & publish: ${NAME} using Docker file ${DOCKER_FILE}"

  # Patch Dockerfile
  if [ "${NO_PATCH}" = "false" ]; then
    patchDockerfile ${DOCKER_FILE} ${FOLDER}
  fi

  IMAGE_URL=${DOCKER_REGISTRY}/${DOCKER_ORG}/${NAME}:${TAG}
  echo Building Docker Image for ${NAME}

  pushd ${FOLDER} > /dev/null 2>&1
  pwd
  
  SET_TARGET=""
  if [ "${TARGET}" != "none" ]; then
    SET_TARGET="--target=${TARGET}"
  fi

  set +e

  docker build ${BUILD_ARGS} ${SET_TARGET} -t ${IMAGE_URL} -f $DOCKER_FILE .
  RETVAL=$?
  if [ $RETVAL -eq 1 ]; then
    unPatchDockerfile ${DOCKER_FILE} ${FOLDER}
    echo "-- Build ${NAME} failed with exit code $RETVAL"
    exit $RETVAL
  fi

  set -e
  #docker tag ${NAME} ${IMAGE_URL}

  if [ "${PUSH}" = "true" ]; then
    echo Pushing Docker Image ${IMAGE_URL}
    docker push  ${IMAGE_URL}
  fi

  if [ "${TAG_LATEST}" = "true" ]; then
    docker tag ${IMAGE_URL} ${DOCKER_REGISTRY}/${DOCKER_ORG}/${NAME}:latest
    if [ "${PUSH}" = "true" ]; then
      echo Pushing Docker Image ${IMAGE_URL}
      docker push ${DOCKER_REGISTRY}/${DOCKER_ORG}/${NAME}:latest
    fi
  fi
  unPatchDockerfile ${DOCKER_FILE} ${FOLDER}

  popd > /dev/null 2>&1
}

function cleanup {
  # Cleanup the SDL/instance defs
  echo
  echo "-- Cleaning up older values.yaml"
  rm -f values.yaml
  # Cleanup prior to generating the UI container
  echo
  echo "-- Cleaning up ${STRATOS_METRICS_PATH}/deploy/containers/nginx/dist"
  rm -rf ${STRATOS_METRICS_PATH}/deploy/containers/nginx/dist

}

function preloadImage {
  docker pull ${DOCKER_REGISTRY}/$1
  docker tag ${DOCKER_REGISTRY}/$1 $1
}

function updateTagForRelease {
  # Reset the TAG variable for a release to be of the form:
  #   <version>-<commit#>-<prefix><hash>
  #   where:
  #     <version> = semantic, in the form major#.minor#.patch#
  #     <commit#> = number of commits since tag - always 0
  #     <prefix> = git commit prefix - always 'g'
  #     <hash> = git commit hash for the current branch
  # Reference: See the examples section here -> https://git-scm.com/docs/git-describe
  pushd ${STRATOS_METRICS_PATH} > /dev/null 2>&1
  GIT_HASH=$(git rev-parse --short HEAD)
  echo "GIT_HASH: ${GIT_HASH}"
  TAG="${TAG}-g${GIT_HASH}"
  if [ "${ADD_OFFICIAL_TAG}" = "true" ]; then
  TAG=${OFFICIAL_TAG}-${TAG}
  fi
  echo "New TAG: ${TAG}"
  popd > /dev/null 2>&1
}

function pushGitTag {
  pushd ${1} > /dev/null 2>&1
  LOCATION=$(pwd -P)
  echo "LOCATION: ${LOCATION}"
  # Create a local tag
  git tag "${TAG}"
  # Push the tag to the shared repo
  git push origin "${TAG}"
  popd > /dev/null 2>&1
}


function patchDockerfile {
  DOCKER_FILE=${1}
  FOLDER=${2}

  # Replace registry/organization
  pushd ${FOLDER} > /dev/null 2>&1
  pwd
  sed -i "s@splatform@${DOCKER_REGISTRY}/${DOCKER_ORG}@g" ${FOLDER}/${DOCKER_FILE}
  sed -i "s/opensuse/${BASE_IMAGE_TAG}/g" ${FOLDER}/${DOCKER_FILE}
  popd > /dev/null 2>&1
}

function unPatchDockerfile {
  DOCKER_FILE=${1}
  FOLDER=${2}

  # Replace registry/organization
  pushd ${FOLDER} > /dev/null 2>&1
  pwd
  sed -i "s@${DOCKER_REGISTRY}/${DOCKER_ORG}@splatform@g" ${FOLDER}/${DOCKER_FILE}
  sed -i "s/${BASE_IMAGE_TAG}/opensuse/g" ${FOLDER}/${DOCKER_FILE}
  popd > /dev/null 2>&1
}

# MAIN ------------------------------------------------------
#

# cleanup output, intermediate artifacts
cleanup

updateTagForRelease

# Build the images for Stratos Metrics
buildAndPublishImage stratos-metrics-configmap-reload Dockerfile.prometheus-helm . configmap-reload
buildAndPublishImage stratos-metrics-kube-state-metrics Dockerfile.prometheus-helm . kube-state-metrics
buildAndPublishImage stratos-metrics-init-chown-data Dockerfile.prometheus-helm . init-chown-data
buildAndPublishImage stratos-metrics-node-exporter Dockerfile.prometheus-helm . node-exporter
buildAndPublishImage stratos-metrics-firehose-init Dockerfile.firehose-init .
buildAndPublishImage stratos-metrics-firehose-exporter Dockerfile.firehose-exporter .
buildAndPublishImage stratos-metrics-nginx Dockerfile.nginx .
buildAndPublishImage stratos-metrics-prometheus Dockerfile.prometheus .

# Show the last 20 images
docker images --filter "reference=${DOCKER_ORG}/stratos-metrics*" --format  "{{.ID | printf \"%-12s\" }}\t{{.Repository | printf \"%-48s\"}}\t{{.Tag | printf \"%-30s\" }}\t{{.CreatedSince | printf \"%-20s\"}}\t{{.Size}}" | head -20

if [ ${CONCOURSE_BUILD:-"not-set"} == "not-set" ]; then
  # Patch Values.yaml file
  pushd ..
  cp values.yaml.tmpl values.yaml
  sed -i -e 's/imageTag: latest/imageTag: '"${TAG}"'/g' values.yaml
  sed -i -e 's/tag: latest/tag: '"${TAG}"'/g' values.yaml
  sed -i -e 's/dockerOrganization: splatform/dockerOrganization: '"${DOCKER_ORG}"'/g' values.yaml

  UPDATED_DOCKER_ORG=${DOCKER_ORG}
  if [ "${DOCKER_REGISTRY}" != "docker.io" ]; then
    UPDATED_DOCKER_ORG="${DOCKER_REGISTRY}\/${UPDATED_DOCKER_ORG}"
  fi
  # The subchart needs full repository
  sed -i -e 's/repository: splatform/repository: '"${UPDATED_DOCKER_ORG}"'/g' values.yaml
  sed -i -e 's/dockerRepository: docker.io/dockerRepository: '"${DOCKER_REGISTRY}"'/g' values.yaml
  popd
else
  # TODO
  sed -i -e 's/consoleVersion: latest/consoleVersion: '"${TAG}"'/g' console/values.yaml
  sed -i -e 's/dockerOrganization: splatform/dockerOrganization: '"${DOCKER_ORG}"'/g' console/values.yaml
  sed -i -e 's/repository: splatform/repository: '"${DOCKER_ORG}"'/g' console/values.yaml
  sed -i -e 's/dockerRepository: docker.io/dockerRepository: '"${DOCKER_REGISTRY}"'/g' console/values.yaml
  
  sed -i -e 's/version: 0.1.0/version: '"${RELEASE_TAG}"'/g' console/Chart.yaml
fi

echo
echo "Stratos Metrics Build complete...."
echo "Registry: ${DOCKER_REGISTRY}"
echo "Org: ${DOCKER_ORG}"
echo "Tag: ${TAG}"
if [ ${CONCOURSE_BUILD:-"not-set"} == "not-set" ]; then
  echo "To deploy using Helm, execute the following: "
  echo "helm install console -f values.yaml --namespace console --name my-console"
fi
