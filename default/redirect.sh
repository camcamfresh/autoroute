#!/bin/sh

# Parse Request
DOMAIN=$(echo $HTTP_HOST | sed -nE 's/(.*\.)?(localhost|127\.0\.0\.1|[^\.]+\.(com|org|net))([:?\/].*)?/\2/p' | tr '[:upper:]' '[:lower:]');
SUBDOMAIN=$(echo $HTTP_HOST | sed -nE "s/(.*)[.]$DOMAIN.*/\1/p" | tr '[:upper:]' '[:lower:]');
PARAMETER=$(echo $REQUEST_URI | sed -nE 's/\/(.*)/\1/p' | sed -E 's/favicon.ico//');

# Subdomain Required for Search
if [[ $SUBDOMAIN ]]; then
    # Divert Local Request
    if [[ $DOMAIN == 'localhost' || $DOMAIN == '127.0.0.1' ]]; then
        # Search Docker & Create Nginx Conf Immediately
        ./buildLocalConf.sh $DOMAIN $SUBDOMAIN $PARAMETER;

        if [ $? -eq 0 ]; then
            source searching.sh 5;
        fi
    else
        # Divert TLD Request
        for RECOGNIZED_DOMAIN in $DOMAINS; do
            if [[ $RECOGNIZED_DOMAIN == $DOMAIN ]]; then
                (./buildLocalConf.sh $DOMAIN $SUBDOMAIN $PARAMETER > /dev/null 2> /dev/null &);
                # ./requestCertbot.sh $DOMAIN $SUBDOMAIN &
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

echo -e "Status: 500 Internal Server Error\n"
return 1;
