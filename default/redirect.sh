#!/bin/sh

# Parse Request
DOMAIN=$(echo $HTTP_HOST | sed -nE 's/(.*\.)?(localhost|127\.0\.0\.1|[^\.]+\.(com|org|net))([:?\/].*)?/\2/p' | tr '[:upper:]' '[:lower:]');
SUBDOMAIN=$(echo $HTTP_HOST | sed -nE "s/(.*)[.]$DOMAIN.*/\1/p" | tr '[:upper:]' '[:lower:]');
PARAMETER=$(echo $REQUEST_URI | sed -nE 's/\/(.*)/\1/p' | sed -E 's/favicon.ico//');

# Subdomain Required for Search
if [[ $SUBDOMAIN ]]; then
    # Divert Local Request
    if [[ $DOMAIN == 'localhost' || $DOMAIN == '127.0.0.1' ]]; then
        # Search Docker & Create Nginx Conf
        ./buildLocalConf.sh $DOMAIN $SUBDOMAIN $PARAMETER &
        echo -e 'Status: 200 OK\n\n';
        cat searching.html;
        return 0;
    else
        # Divert TLD Request
        for TLD in $DOMAINS; do
            if [[ $TLD == $DOMAIN ]]; then
                ./buildLocalConf.sh $DOMAIN $SUBDOMAIN $PARAMETER &
                ./requestCertbot.sh $DOMAIN $SUBDOMAIN &
                cat searching.html;
                return 0;
                # Create Local Redirect
                # Start SSL
            fi
        done
    fi
fi

# Return Not Found
echo -e 'Status: 404 Not Found\n\n';
cat not_found.html;
return 0;

