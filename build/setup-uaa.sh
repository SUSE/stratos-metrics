#!/bin/bash

ARGS=""
if [ ! -z "${SKIP_SSL_VALIDATION}" ]; then
 ARGS="--skip-ssl-validation"
fi
uaac.ruby2.1 target ${ARGS} https://${UAA_ENDPOINT}
uaac.ruby2.1 token client get admin -s ${UAA_ADMIN_SECRET}
uaac.ruby2.1 -t curl -k -H"X-Identity-Zone-Id:${CF_IDENTITY_ZONE}" -XPOST -H"Content-Type:application/json" -H"Accept:application/json" --data '{ "client_id" : "prom_admin", "client_secret" : "${UAA_ADMIN_SECRET}", "scope" : ["uaa.none"], "resource_ids" : ["none"], "authorities" : ["uaa.admin","clients.read","clients.write","clients.secret","scim.read","scim.write","clients.admin"], "authorized_grant_types" : ["client_credentials"]}' /oauth/clients
uaac.ruby2.1 target ${ARGS} https://${CF_IDENTITY_ZONE}.${UAA_ENDPOINT}
uaac.ruby2.1 token client get prom_admin -s ${UAA_ADMIN_SECRET}
uaac.ruby2.1 client add prometheus-firehose \
  --name prometheus-firehose \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose