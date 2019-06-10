#!/bin/bash
set -x

# This script creates a client in the UAA that has the authority to read from the CF Firehose

ARGS=""
if [ ! -z "${SKIP_SSL_VALIDATION}" ]; then
 ARGS="--skip-ssl-validation"
fi

# Zone arg for UAAC
ZONE_ARG=""
ZONE_NAME="<Default>"
if [ ! -z "${ZONE}" ]; then
  ZONE_ARG="-z ${ZONE}"
  ZONE_NAME=${ZONE}
fi

# Authority
# UAA_AUTHORITY

set +x

echo
echo "Cloud Foundry Doppler URL         : ${DOPPLER_ENDPOINT}"
echo "UAA Endpoint                      : ${UAA_ENDPOINT}"
echo "Root UAA Endpoint                 : ${ROOT_UAA_ENDPOINT}"
echo "Zone                              : ${ZONE}"
echo "UAA Authority                     : ${PROMETHEUS_CLIENT}"
echo "UAA Client to create              : ${UAA_AUTHORITY}"
echo ""

uaac target ${ARGS} ${ROOT_UAA_ENDPOINT}
uaac token client get ${UAA_ADMIN} -s ${UAA_ADMIN_SECRET}
if [ $? -ne 0 ]; then
  echo "Failed to log into the UAA default zone as ${UAA_ADMIN}"
  exit 1
fi

# Check if the prometheus client exists in the zone
uaac client get ${ZONE_ARG} ${PROMETHEUS_CLIENT}
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "UAA Client: ${PROMETHEUS_CLIENT} does NOT exist - creating ... (Zone: ${ZONE_NAME})"
  uaac client add ${ZONE_ARG} ${PROMETHEUS_CLIENT} \
    --name ${PROMETHEUS_CLIENT} \
    --secret ${PROMETHEUS_CLIENT_SECRET} \
    --authorized_grant_types client_credentials,refresh_token \
    --authorities doppler.firehose
  echo "UAA Client: ${PROMETHEUS_CLIENT} created in zone ${ZONE_NAME}"
else
  # Update the client secret, in case it has changed
  echo "UAA Client: ${PROMETHEUS_CLIENT} already exists - updating secret"
  uaac secret set ${ZONE_ARG} ${PROMETHEUS_CLIENT} -s ${PROMETHEUS_CLIENT_SECRET}
  EXIT_CODE=$?
  if [ $EXIT_CODE -ne 0 ]; then
    echo "Failed to update client secret for UAA Client: ${PROMETHEUS_CLIENT} (Zone: ${ZONE_NAME})"
    exit ${EXIT_CODE}
  fi
  echo "Updated client secret"
fi

# For good measure, retrieve and display the newly created client
uaac client get ${ZONE_ARG} ${PROMETHEUS_CLIENT}
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Failed to get newly created client: ${PROMETHEUS_CLIENT}"
  exit ${EXIT_CODE}
fi

# All done
echo "Metrics UAA Setup completed"
