#!/bin/sh

# Parse Request
DOMAIN=$(echo $HTTP_HOST | sed -nE 's/(.*\.)?(localhost|127\.0\.0\.1|[^\.]+\.(com|org|net))([:?\/].*)?/\2/p' | tr '[:upper:]' '[:lower:]');
SUBDOMAIN=$(echo $HTTP_HOST | sed -nE "s/(.*)[.]$DOMAIN.*/\1/p" | tr '[:upper:]' '[:lower:]');
PARAMETER=$(echo $REQUEST_URI | sed -nE 's/\/(.*)/\1/p' | sed -E 's/favicon.ico//');

if [[ $PARAMETER ]]; then
    echo "redirect.sh: Redirecting $SUBDOMAIN request for $DOMAIN searching for container $PARAMETER" > "$STDOUT"
else
    echo "redirect.sh: Redirecting $SUBDOMAIN request for $DOMAIN searching for container $SUBDOMAIN" > "$STDOUT"
fi

# Subdomain Required for Search
if [[ $SUBDOMAIN ]]; then
    # Divert Local Request
    if [[ $DOMAIN == 'localhost' || $DOMAIN == '127.0.0.1' ]]; then
        # Search Docker & Create Nginx Conf Immediately
        ./createConf.py "SSL_OFF" "$DOMAIN" "$SUBDOMAIN" "$PARAMETER";

        if [ $? -eq 0 ]; then
            source searching.sh 5;
        fi
    else
        # Divert TLD Request
        for RECOGNIZED_DOMAIN in $DOMAINS; do
            if [[ $RECOGNIZED_DOMAIN == $DOMAIN ]]; then
                # Search Docker & Create Nginx HTTP Conf
                ./createConf.py "SSL_OFF" "$DOMAIN" "$SUBDOMAIN" "$PARAMETER";
                
                STATUS=$?
                if [[ $STATUS -ne 1 ]]; then
                    # Start SSL Certificate Process
                    # fcgiwrap is attached to the stdout/err file
                    #  we must close its output to start it as a backgroud process
                    ./requestCert.sh "$DOMAIN" "$SUBDOMAIN" "$PARAMETER" > /dev/null 2> /dev/null &

                    # If HTTP Config was successful redirect there, otherwise wait for SSL
                    if [[ $STATUS -eq 0 ]]; then
                        source searching.sh 5;
                    elif [[ $STATUS -eq 2 ]]; then
                        source searching.sh 60;
                    fi
                fi
            fi
        done
    fi
fi

# Return Not Found
source not_found.sh;

# Should never reach this point.
echo -e "Status: 500 Internal Server Error\n"
return 1;
