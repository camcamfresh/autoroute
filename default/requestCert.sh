#!/bin/sh

# Check for Enviroment Variables
if [[ ! $1 ]]; then
	echo 'Domain must be provided to issue certificate.' > "$STDERR";
	exit 1;
elif [[ ! $2 ]]; then
    echo 'Subdomain must be provided to issue certificate.' > "$STDERR";
elif [[ ! "$EMAIL" ]]; then
	echo 'Enviroment Variable "EMAIL" is not set.' > "$STDERR";
	exit 1;
elif [[ ! "$CONFIG_DIR" ]]; then
	echo 'Enviroment Variable "CONFIG_DIR" is not set.' > "$STDERR";
	exit 1
elif [[ ! -r "$CONFIG_DIR/luadns.ini" ]]; then
	echo "Credential file luadns.ini was not found in $CONFIG_DIR." > "$STDERR";
	exit 1;
fi

REQUESTED_DOMAIN="$2.$1"
echo "Requesting Certificate for $REQUESTED_DOMAIN"
# Run Certbot for Each Domain.
certbot certonly \
    --agree-tos \
    --expand \
    --config-dir "$CONFIG_DIR/data" \
    --dns-luadns \
    --dns-luadns-credentials "$CONFIG_DIR/luadns.ini" \
    -d "$REQUESTED_DOMAIN" \
    -m "$EMAIL" \
    -n > "$STDOUT" 2> "$STDERR";

# Copy SSL Certificates in data/live/{REQUESTED_DOMAIN} to /certs/{REQUESTED_DOMAIN}.
echo "Placing Certificates in /certs directory" > "$STDOUT"
REQUESTED_DOMAIN_DIR="$CONFIG_DIR/data/live/$REQUESTED_DOMAIN";
if [[ -d "$REQUESTED_DOMAIN_DIR" ]]; then
	[[ -d "$CONFIG_DIR/certs/$REQUESTED_DOMAIN" ]] || mkdir -p "$CONFIG_DIR/certs/$REQUESTED_DOMAIN";
	
    # Loop through each symbolic link in directory
    for LINK in $(ls -Al "$REQUESTED_DOMAIN_DIR" | sed -ne '/^l.*/p' | sed -Ee 's/^.* (.*) -> (.*)$/\1;\2/'); do		
        NAME=$(echo $LINK | sed -Ee 's/^(.*);.*$/\1/');
        LOCATION=$(echo $LINK | sed -Ee 's/^.*;\.\.\/\.\.\/(.*)$/\1/');
        cp "$CONFIG_DIR/data/$LOCATION" "$CONFIG_DIR/certs/$REQUESTED_DOMAIN/$NAME";
    done;
fi

echo "Creating Nginx Certificate File" > "$STDOUT"
[[ -d /etc/nginx/ssl.d/$REQUESTED_DOMAIN ]] || mkdir -p /etc/nginx/ssl.d/$REQUESTED_DOMAIN/;
cat ssl.conf | sed "s/{SERVER_NAME}/$REQUESTED_DOMAIN/g" > /etc/nginx/ssl.d/$REQUESTED_DOMAIN/ssl.conf;
cp "$CONFIG_DIR/certs/$REQUESTED_DOMAIN/fullchain.pem" "/etc/nginx/ssl.d/$REQUESTED_DOMAIN/fullchain.pem";
cp "$CONFIG_DIR/certs/$REQUESTED_DOMAIN/privkey.pem" "/etc/nginx/ssl.d/$REQUESTED_DOMAIN/privkey.pem";

echo "Requesting SSL Enabled Configuration File" > "$STDOUT"
./createConf.py "SSL_ON" "$1" "$2" "$3";
exit 0;
