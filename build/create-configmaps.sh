#!/bin/bash
#set -x

echo "===================================="
echo "Metrics - Endpoint Config Generation"
echo "===================================="
echo ""

# Generate ConfigMap based on the env vars

# FIREHOSE_EXPORTER_ENABLED
# KUBE_STATE_EXPORTER_ENABLED
# KUBE_NODE_EXPORTER_ENABLED
# CONFIGMAP_NAME
# NGINX_CONFIG_MAP
# KUBE_API_URL
# CF_URL
# DOPPLER_URL (optional)

NGINX_CONFIG_MAP="${RELEASE_NAME}-stratos-metrics-config"

echo "Firehose Exporter Enabled         : ${FIREHOSE_EXPORTER_ENABLED}"
echo "Kubernetes State Exporter Enabled : ${KUBE_STATE_EXPORTER_ENABLED}"
echo "Kubernetes Node Exporter Enabled  : ${KUBE_NODE_EXPORTER_ENABLED}"
echo "Kubernetes API URL                : ${KUBE_API_URL}"
echo "Cloud Foundry API URL             : ${CF_URL}"
echo "Cloud Foundry Doppler URL         : ${DOPPLER_URL}"
echo "ConfigMap Name                    : ${CONFIGMAP_NAME}"
echo "nginx ConfigMap Name              : ${NGINX_CONFIG_MAP}"
echo ""

# Function to get info from the Cloud Foundry API
function getCloudFoundryInfo() {

  # Need the CF API URL
  if [ ! -n "${CF_URL}" ]; then
    echo "FAIL: Cloud Foundry API URL must be provided in CF_URL"
    exit 1
  fi

  INFO_URL="${CF_URL}/v2/info"

  echo "Fetching info from Cloud Foundry: ${INFO_URL} ..."

  JSON_FILE=$(mktemp)

  curl -s --fail -k ${INFO_URL} > $JSON_FILE
  if [ $? -ne 0 ]; then
    echo "FAIL: Could not get /v2/info for the Cloud Foundry"
    exit 1
  fi

  echo "Got info OK"

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

  echo ""
  echo "Doppler Endpoint     : $DOPPLER_ENDPOINT"
  echo "UAA Endpoint         : $UAA_ENDPOINT"
  echo ""
  rm -rf $JSON_FILE

  # Get the UAA info, so we can work out the root UAA from the zone (if applicable)

  echo "Fetching UAA info from ${UAA_ENDPOINT}"
  curl -s --fail -k -L -H "Accept: application/json" ${UAA_ENDPOINT} > $JSON_FILE
  if [ $? -ne 0 ]; then
    echo "FAIL: Could not get UAA Endpoint metadata"
    exit 1
  fi

  echo "Got UAA info OK"

  ZONE_NAME=$(jq -r .zone_name $JSON_FILE)
  if [ $? -ne 0 ]; then
    echo "FAIL: Could not get UAA Zone Name"
    exit 1
  fi

  rm -rf $JSON_FILE
  echo ""
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
    ROOT_UAA_ENDPOINT=${URL}
  fi

  echo "Root UAA Endpoint    : $ROOT_UAA_ENDPOINT"
  echo ""

  echo "Fetching Root UAA info ..."

  curl -s --fail -k -L -H "Accept: application/json" ${ROOT_UAA_ENDPOINT} > $JSON_FILE
  if [ $? -ne 0 ]; then
    echo "FAIL: Could not get Root UAA Endpoint metadata"
    exit 1
  fi

  echo "Got Root UAA info OK"

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

  echo ""
  echo "Root UAA URL verified: ${ROOT_UAA_ENDPOINT}"

  # ===========================================================================

  # At this point, we should have the following env vars:

  # ROOT_UAA_ENDPOINT
  # ZONE_NAME
  # DOPPLER_ENDPOINT
  # UAA_ENDPOINT

  # ===========================================================================
}


# ===========================================================================
# ===========================================================================
# Main Script Start Point
# ===========================================================================
# ===========================================================================

if [ "${FIREHOSE_EXPORTER_ENABLED}" == "true" ]; then
  getCloudFoundryInfo

  # Do we have DOPPLER_URL set to a non-empty value?
  if [ ! -z "${DOPPLER_URL}" ]; then
    echo "Overriding Dopper Endpoint to: ${DOPPLER_URL}"
    DOPPLER_ENDPOINT="${DOPPLER_URL}"
  fi
fi

# Need to create a config map with these values in, that other containers can access
# Values set depend on what exporters are enabled

# Also need to patch the nginx config to update the Stratos Marker file based on
# which exporters are enabled

# Kubernetes token
KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
KUBE_API_SERVER=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT

# Check whether the config map already exists
curl -k \
    --fail \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Content-Type: application/json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/configmaps/${CONFIGMAP_NAME} > /dev/null

EXISTS=$?
if [ $EXISTS -ne 0 ]; then
  echo "Metrics Endpoint ConfigMap does not exist - creating new one"

cat << EOF > create-configMap.yaml
{
  "kind": "ConfigMap",
  "apiVersion": "v1",
  "data": {},
  "metadata": {
EOF

  echo "\"name\": \"${CONFIGMAP_NAME}\"" >> create-configMap.yaml
  echo "}}" >> create-configMap.yaml
  cat create-configMap.yaml

  curl -k \
    --fail \
    -X POST \
    -d @create-configMap.yaml \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/configmaps > /dev/null

  RET_CREATE=$?
  echo "Create Metrics ConfigMap exit code: $RET_CREATE"
  rm -rf create-configMap.yaml
  if [ $RET_CREATE -ne 0 ]; then
    echo "Error creating Metrics Config secret"
    exit $RET_CREATE
  fi
else
  echo "Metrics Config ConfigMap exists: ${CONFIGMAP_NAME}"
fi

# Update the secret based on the env vars

cat << EOF > patch-configMap.yaml
{
  "kind": "ConfigMap",
  "apiVersion": "v1",
  "metadata": {
EOF
echo "\"name\": \"${CONFIGMAP_NAME}\"" >> patch-configMap.yaml
echo "}," >> patch-configMap.yaml

echo "\"data\": {" >> patch-configMap.yaml
echo "\"zone\": \"${ZONE_NAME}\"," >> patch-configMap.yaml
echo "\"root_uaa_endpont\": \"${ROOT_UAA_ENDPOINT}\"," >> patch-configMap.yaml
echo "\"doppler_endpoint\": \"${DOPPLER_ENDPOINT}\"," >> patch-configMap.yaml
echo "\"uaa_endpoint\": \"${UAA_ENDPOINT}\"" >> patch-configMap.yaml
echo "} }" >> patch-configMap.yaml

echo "Patching ConfigMap for the Endpoint Config"

cat patch-configMap.yaml

echo ""

    #-H 'Content-Type: application/merge-patch+json' \

# Patch ConfigMap for the Metrics Endpoint Config
curl -k \
    --fail \
    -X PUT \
    -d @patch-configMap.yaml \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/configmaps/${CONFIGMAP_NAME} > /dev/null

RET_PATCH=$?
echo "Patch Metrics Endpoint ConfigMap exit code: $RET_PATCH"
rm -rf patch-configMap.yaml
if [ $RET_PATCH -ne 0 ]; then
  echo "Error patching Metrics Endpoint ConfigMap"
  exit $RET_PATCH
fi

echo "Metrics Endpoint ConfigMap created/updated OK"
echo "  + ${CONFIGMAP_NAME} in namespace ${NAMESPACE}"

# Now update the nginx config map to have the endpoint metadata

printf "{\"data\": {" > patch-nginx-configMap.json
printf "\"nginx-metadata\": \"[" >> patch-nginx-configMap.json

FIRST="true"

# Add Cloud Foundry metadata if the exporter is enabled
if [ "${FIREHOSE_EXPORTER_ENABLED}" == "true" ]; then
  printf '%s' "{\\\"type\\\": \\\"cf\\\"," >> patch-nginx-configMap.json
  printf '%s' "\\\"url\\\": \\\"${DOPPLER_ENDPOINT}\\\"," >> patch-nginx-configMap.json
  printf '%s' "\\\"cfEndpoint\\\": \\\"${CF_URL}\\\"," >> patch-nginx-configMap.json
  printf '%s' "\\\"job\\\": \\\"cf-firehose\\\"" >> patch-nginx-configMap.json
  printf "}" >> patch-nginx-configMap.json
  FIRST="false"
fi

if [ "${KUBE_STATE_EXPORTER_ENABLED}" == "true" ]; then
  if [ "${FIRST}" == "true" ]; then
    printf "," >> patch-nginx-configMap.json
  fi
  printf '%s' "\\\"type\\\": \\\"k8s\\\"," >> patch-nginx-configMap.json
  printf '%s' "\\\"url\\\": \\\"${KUBE_API_URL}\\\"," >> patch-nginx-configMap.json
  printf '%s' "\\\"job\\\": \\\"k8s-metrics\\\"" >> patch-nginx-configMap.json
  printf '%s' "}" >> patch-nginx-configMap.json
fi

printf "]\" } }" >> patch-nginx-configMap.json

echo "Ready to patch nginx configuration"
cat patch-nginx-configMap.json | jq . >  patch-nginx-configMap2.json
cat patch-nginx-configMap2.json
echo ""

echo "Patching nginx configuration"

curl -k \
    --fail \
    -X PATCH \
    -d @patch-nginx-configMap2.json \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/merge-patch+json' \
    ${KUBE_API_SERVER}/api/v1/namespaces/${NAMESPACE}/configmaps/${NGINX_CONFIG_MAP} > /dev/null

RET_PATCH=$?
echo "Patch Metrics nginx ConfigMap exit code: $RET_PATCH"
rm -rf patch-nginx-configMap.json
rm -rf patch-nginx-configMap2.json
if [ $RET_PATCH -ne 0 ]; then
  echo "Error patching Metrics nginx ConfigMap"
  exit $RET_PATCH
fi

echo "Metrics Endpoint nginx updated OK"
echo "  + ${NGINX_CONFIG_MAP} in namespace ${NAMESPACE}"

