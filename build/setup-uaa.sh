#!/bin/bash
set -x

# SKIP_SSL_VALIDATION="true"
# UAA_ENDPOINT="uaa.cf-dev.io:2793"
# UAA_ADMIN_SECRET="admin_secret"
# UAA_ADMIN="admin"
# CF_IDENTITY_ZONE="cf"

# PROMETHEUS_ADMIN_CLIENT="prom_admin"
# PROMETHEUS_ADMIN_CLIENT_SECRET="prom_admin_secret"
# PROMETHEUS_CLIENT="prometheus-firehose"
# PROMETHEUS_CLIENT_SECRET="prometheus-client-secret"
ARGS=""

get_post_data(){
  cat << EOF
  { "client_id" : "${PROMETHEUS_ADMIN_CLIENT}", 
    "client_secret" : "${PROMETHEUS_ADMIN_CLIENT_SECRET}", 
    "scope" : ["uaa.none"], 
    "resource_ids" : ["none"], 
    "authorities" : ["uaa.admin","clients.read","clients.write","clients.secret","scim.read","scim.write","clients.admin"], 
    "authorized_grant_types" : ["client_credentials"]
  }
EOF
}
if [ ! -z "${SKIP_SSL_VALIDATION}" ]; then
 ARGS="--skip-ssl-validation"
fi
uaac.ruby2.1 target ${ARGS} https://${UAA_ENDPOINT}
uaac.ruby2.1 token client get ${UAA_ADMIN} -s ${UAA_ADMIN_SECRET}
# Check if client already exists
clientGetResponse=$(uaac.ruby2.1 -t curl -k -H"X-Identity-Zone-Id:${CF_IDENTITY_ZONE}" -XGET /oauth/clients/${PROMETHEUS_ADMIN_CLIENT})
clientExists=""
responseWas200=$(echo $clientGetResponse | grep "200")
responseWas404=$(echo $clientGetResponse | grep "404")
if [ ! -z "${responseWas404}" ]; then
# Create client
uaac.ruby2.1 -t curl -k -H"X-Identity-Zone-Id:${CF_IDENTITY_ZONE}" -XPOST -H"Content-Type:application/json" -H"Accept:application/json" --data "$(get_post_data)" /oauth/clients
elif [ ! -z "${responseWas200}" ]; then
echo "Client ${PROMETHEUS_ADMIN} in zone ${CF_IDENTITY_ZONE} already exists"
elif [ -z "${responseWas200}" && -z "${responseWas404}" ]; then
echo "Something unexpected happened. UAA Response was: ${clientGetResponse}"
exit 1
fi

uaac.ruby2.1 target ${ARGS} https://${CF_IDENTITY_ZONE}.${UAA_ENDPOINT}
uaac.ruby2.1 token client get prom_admin -s ${PROMETHEUS_ADMIN_CLIENT_SECRET}

# Check if client has already been created
uaac.ruby2.1 client get ${PROMETHEUS_CLIENT}
EXIT_CODE=$?
if [ $EXIT_CODE -eq 1 ]; then
uaac.ruby2.1 client add ${PROMETHEUS_CLIENT} \
  --name prometheus-firehose \
  --secret ${PROMETHEUS_CLIENT_SECRET} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose
fi

