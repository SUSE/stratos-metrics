#!/bin/bash

# Metrics

patchHelmChart () {
  local TAG=$1
  local DOCKER_ORG=$2
  local DOCKER_REG=$3
  local CHART_PATH=$4
  local CHART_VERSION=$5

  # Patch Helm chart
  sed -i -e 's/imageTag: [a-z0-9\.-]*/imageTag: '"${TAG}"'/g' ${CHART_PATH}/values.yaml
  sed -i -e 's/tag: .*/tag: '"${TAG}"'/g' ${CHART_PATH}/values.yaml
  sed -i -e 's@repository: splatform@repository: '"${DOCKER_REG}"'/'"${DOCKER_ORG}"'@g' ${CHART_PATH}/values.yaml
  sed -i -e 's/dockerOrganization: splatform/dockerOrganization: '"${DOCKER_ORG}"'/g' ${CHART_PATH}/values.yaml
  sed -i -e 's/dockerRepository: docker.io/dockerRepository: '"${DOCKER_REG}"'/g' ${CHART_PATH}/values.yaml
  sed -i -e 's/version: [0-9].[0-9].[0-9]/version: '"${CHART_VERSION}"'/g' ${CHART_PATH}/Chart.yaml  

  # Patch the image tag in place - otherwise --reuse-values won't work with helm upgrade
  sed -i -e 's/{{.Values.imageTag}}/'"${TAG}"'/g' ${CHART_PATH}/templates/deployment.yaml
  sed -i -e 's/{{$values.imageTag}}/'"${TAG}"'/g' ${CHART_PATH}/templates/deployment.yaml
  sed -i -e 's/{{.Values.imageTag}}/'"${TAG}"'/g' ${CHART_PATH}/templates/config-job.yaml
  sed -i -e 's/{{$values.imageTag}}/'"${TAG}"'/g' ${CHART_PATH}/templates/config-job.yaml

  sed -i -e 's/{{.Values.imageTag}}/'"${TAG}"'/g' ${CHART_PATH}/templates/cf-exporter.yaml
  sed -i -e 's/{{$values.imageTag}}/'"${TAG}"'/g' ${CHART_PATH}/templates/cf-exporter.yaml

}

patchHelmChartDev () {
  local TAG=$1
  local DOCKER_ORG=$2
  local DOCKER_REG=$3
  local CHART_PATH=$4
  local CHART_VERSION=$5
  local APP_VERSION=$6
  patchHelmChart ${TAG} ${DOCKER_ORG} ${DOCKER_REG} ${CHART_PATH} ${CHART_VERSION} ${APP_VERSION}

  sed -i -e 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' ${CHART_PATH}/values.yaml  
}

setupAndPushChange() {
  setupGitConfig
  git stash
  git pull --rebase
  git stash pop
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
  git add index.yaml
  git commit -m "Helm repository updated for tag: ${IMAGE_TAG}"
  git config --global push.default simple
  git push origin HEAD:${HELM_REPO_BRANCH}
}

setupGitConfig() {
  git config --global user.name ${GIT_USER}
  git config --global user.email ${GIT_EMAIL}

  mkdir -p /root/.ssh/
  echo "${GIT_PRIVATE_KEY}" > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
}

updateHelmDependency() {
  local START_CWD=$(pwd)
  cd ${STRATOS_METRICS}
  # Only do this if there is a requirements.yaml file
  if [ -f "./requirements.yaml" ]; then
    # Extract helm repo
    local HELM_REPO=$(cat requirements.yaml | grep repo | sed -e 's/.*repository:\s\(.*\)/\1/p' | head -1)
    helm repo add repo ${HELM_REPO}
    helm dependency update
  fi
  cd ${START_CWD}
}
