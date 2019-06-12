#!/bin/bash

echo "Firehose exporter"

# Wait for the client

SSL_VERIFY=""
if [ "${FIREHOSE_EXPORTER_SKIP_SSL_VERIFY}" == "true" ]; then
  SSL_VERIFY=" --skip-ssl-validation"
fi

uaac target ${FIREHOSE_EXPORTER_UAA_URL} ${SSL_VERIFY}

READY="false"
while [ "$READY" == "false" ]; do 

  uaac token client get ${FIREHOSE_EXPORTER_UAA_CLIENT_ID} -s ${FIREHOSE_EXPORTER_UAA_CLIENT_SECRET}
  if [ $? -ne 0 ]; then
    echo "Can't login to UAAC .. client not ready"
    echo "Waiting..."
    sleep 15
  else
    echo "Logged in to UAAC OK"
    READY="true"
  fi

done

echo "Starting firehose exporter"

/bin/firehose_exporter