#!/bin/bash
#set -x

echo "==========================="
echo "Metrics - Secret Generation"
echo "==========================="

# Need the CF API URL
CF_URL=https://api.192.168.39.187.xip.io/v2/info

if [ ! -n "${CF_URL}" ]; then
  echo "FAIL: Cloud Foundry API URL must be provided in CF_URL"
  exit 1
fi

JSON_FILE=$(mktemp)

curl -s --fail -k ${CF_URL} > $JSON_FILE
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get /v2/info for the Cloud Foundry"
  exit 1
fi

DOPPLER_ENDPOINT=$(jq -r .doppler_logging_endpoint $JSON_FILE)
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get Doppler Endpoint for the Cloud Foundry"
  exit 1
fi

UAA_ENDPOINT=$(jq -r .authorization_endpoint $JSON_FILE)
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get UAA Endpoint for the Cloud Foundry"
  exit 1
fi

echo "Doppler Endpoint     : $DOPPLER_ENDPOINT"
echo "UAA Endpoint         : $UAA_ENDPOINT"
rm -rf $JSON_FILE

# Get the UAA info, so we can work out the root UAA from the zone (if applicable)

UAA_ENDPOINT=https://scf.uaa.192.168.39.187.xip.io:2793

curl -s --fail -k -L -H "Accept: application/json" ${UAA_ENDPOINT} > $JSON_FILE
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get UAA Endpoint metadata"
  exit 1
fi

ZONE_NAME=$(jq -r .zone_name $JSON_FILE)
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get UAA Zone Name"
  exit 1
fi

rm -rf $JSON_FILE
echo "UAA Zone             : $ZONE_NAME"

if [ "${ZONE_NAME}" == "uaa" ]; then
  echo "Using the default UAA Zone: uaa"
  # There is no zone name - its the default
  ZONE_NAME=""
  ROOT_UAA_ENDPOINT=${UAA_ENDPOINT}
else
  # Take the zone off of the UAA_ENDPOINT to get the root UAA Endpoint
  URL=$(echo $UAA_ENDPOINT | sed -e 's$https://'"${ZONE_NAME}"'.$https://$')
  URL=$(echo $URL | sed -e 's$http://'"${ZONE_NAME}"'.$http://$')
fi

ROOT_UAA_ENDPOINT=${URL}
curl -s --fail -k -L -H "Accept: application/json" ${ROOT_UAA_ENDPOINT} > $JSON_FILE
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get Root UAA Endpoint metadata"
  exit 1
fi
ROOT_ZONE_NAME=$(jq -r .zone_name $JSON_FILE)
if [ $? -ne 0 ]; then
  echo "FAIL: Could not get Root UAA Zone Name"
  exit 1
fi

rm -rf $JSON_FILE

if [ "${ROOT_ZONE_NAME}" != "uaa" ]; then
  echo "FAIL: Root UAA should have zone 'uaa'"
  exit 1
fi

echo "Root UAA URL         : ${ROOT_UAA_ENDPOINT}"

# ===========================================================================

# At this point, we should have the following env vars:

# ROOT_UAA_ENDPOINT
# ZONE_NAME
# DOPPLER_ENDPOINT
# UAA_ENDPOINT

# ===========================================================================

# Need to create a secret with these values in, that other containers can access

# Kubernetes token
KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
KUBE_API_SERVER=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT

# Check whether the secret already exists
curl -k \
    --fail \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Content-Type: application/json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/secrets/${RELEASE_NAME}-config-secret > /dev/null

EXISTS=$?
if [ $EXISTS -ne 0 ]; then
  echo "Metrics Config Secret does not exist - creating new one"

  # TODO
cat << EOF > create-secret.yaml
{
  "kind": "Secret",
  "apiVersion": "v1",
  "data": {}
}
EOF

  curl -k \
    --fail \
    -X POST \
    -d @create-secret.yaml \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/secrets/${RELEASE_NAME}-config-secret > /dev/null

  RET_CREATE=$?
  echo "Create Metrics Config secret exit code: $RET_CREATE"
  rm -rf create-secret.yaml
  if [ $RET_PATCH -ne 0 ]; then
    echo "Error cerating Metrics Config secret"
    exit $RET_PATCH
  fi
fi

# Update the secret based on the env vars

cat << EOF > patch-secret.yaml
{
  "data": {
EOF

echo "\"zone\": \"${ZONE_NAME}\"" >> patch-secret.yaml
echo "\"root_uaa_endpont\": \"${ROOT_UAA_ENDPOINT}\"" >> patch-secret.yaml
echo "\"doppler_endpoint\": \"${DOPPLER_ENDPOINT}\"" >> patch-secret.yaml
echo "\"uaa_endpoint\": \"${UAA_ENDPOINT}\"" >> patch-secret.yaml
echo "} }" >> patch-secret.yaml

echo "Patching secret for the Metrics Config"

# Patch secret for the Metrics Config
curl -k \
    --fail \
    -X PATCH \
    -d @patch-secret.yaml \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/merge-patch+json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/secrets/${RELEASE_NAME}-config-secret > /dev/null

RET_PATCH=$?
echo "Patch Metrics Config secret exit code: $RET_PATCH"
rm -rf patch-secret.yaml
if [ $RET_PATCH -ne 0 ]; then
  echo "Error patching Metrics Config secret"
  exit $RET_PATCH
fi

echo "Metrics Config secret created/updated OK"
echo "  + ${RELEASE_NAME}-config-secret in namespace ${NAMESPACE}"
