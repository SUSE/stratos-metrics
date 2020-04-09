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

echo "Starting nginx"
nginx -g "daemon off;"

