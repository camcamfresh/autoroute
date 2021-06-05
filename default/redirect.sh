#!/bin/sh

# Parse Request
DOMAIN=$(echo $HTTP_HOST | sed -nE 's/(.*\.)?(localhost|127\.0\.0\.1|[^\.]+\.(com|org|net))([:?\/].*)?/\2/p' | tr '[:upper:]' '[:lower:]');
SUBDOMAIN=$(echo $HTTP_HOST | sed -nE "s/(.*)[.]$DOMAIN.*/\1/p" | tr '[:upper:]' '[:lower:]');
PARAMETER=$(echo $REQUEST_URI | sed -nE 's/\/(.*)/\1/p' | sed -E 's/favicon.ico//');

if [[ $PARAMETER ]]; then
    echo "redirect.sh: Redirecting $SUBDOMAIN request for $DOMAIN searching for container $PARAMETER" > /dev/stderr
else
    echo "redirect.sh: Redirecting $SUBDOMAIN request for $DOMAIN searching for container $SUBDOMAIN" > /dev/stderr
fi

# Subdomain Required for Search
if [[ $SUBDOMAIN ]]; then
    # Divert Local Request
    if [[ $DOMAIN == 'localhost' || $DOMAIN == '127.0.0.1' ]]; then
        # Search Docker & Create Nginx Conf Immediately
        ./createConf.py "SSL_OFF" $DOMAIN $SUBDOMAIN $PARAMETER;

        if [ $? -eq 0 ]; then
            source searching.sh 5;
        fi
    else
        # Divert TLD Request
        for RECOGNIZED_DOMAIN in $DOMAINS; do
            if [[ $RECOGNIZED_DOMAIN == $DOMAIN ]]; then
                ./createConf.py "SSL_OFF" $DOMAIN $SUBDOMAIN $PARAMETER;
                # ./requestCert.sh $DOMAIN $SUBDOMAIN > /dev/stderr 2> /dev/stderr &
                if [ $? -eq 0 ]; then
                    source searching.sh 60;
                fi
                # Create Local Redirect
                # Start SSL
            fi
        done
    fi
fi

# Return Not Found
source not_found.sh;

# Should never reach this point.
echo -e "Status: 500 Internal Server Error\n"
return 1;
