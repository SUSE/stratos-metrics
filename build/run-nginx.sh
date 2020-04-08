#!/bin/bash
echo "Checking if certificate has been supplied!"
while : 
do 
    if [ -f /etc/secrets/cert.crt ]; then
        break;
    fi
    sleep 1; 
done
echo "TLS certificate detected continuing, starting nginx."

echo "Create username/password for authentication"
htpasswd -b -c /etc/nginx/.htpasswd $USERNAME $PASSWORD

echo "Update /etc/hosts with the prometheus IP"

HOST="prometheus-server"

# Get the IP address for the service name (depends on release name)
RS=$(echo "$RELEASE_NAME" | awk '{print toupper($0) }')
RS=${RS//-/_}
ENVVAR="${RS}_PROMETHEUS_PROMETHEUS_SERVICE_HOST"
VALUE=$(printf '%s\n' "${!ENVVAR}")
if [ -n "${VALUE}" ]; then
    echo "Updating /etc/hosts with Prometheus server IP ${VALUE}"
    echo "${VALUE}    ${HOST}" >> /etc/hosts
else
    echo "Could not find IP for Prometheus server"
    echo $NS
    echo $ENVVAR
fi

echo "Starting nginx"
nginx -g "daemon off;"

