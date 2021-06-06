#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html

# An unknown request will by redirected to fcgiwrap by default.conf. 
# fcgiwrap calls this script and monitors both stdin and stdout for output.
# In order to enable proper logging we change the file descriptors until a response is ready.
exec 3<&1 4<&2 1<> /var/log/autocert/stdout.log 2<> /var/log/autocert/stderr.log;

restore_output() {
    exec 1<&- 2<&- 1<&3 2<&4;
}

# Parse Request
DOMAIN=$(echo $HTTP_HOST | sed -nE 's/(.*\.)?(localhost|127\.0\.0\.1|[^\.]+\.(com|org|net))([:?\/].*)?/\2/p' | tr '[:upper:]' '[:lower:]');
SUBDOMAIN=$(echo $HTTP_HOST | sed -nE "s/(.*)[.]$DOMAIN.*/\1/p" | tr '[:upper:]' '[:lower:]');
PARAMETER=$(echo $REQUEST_URI | sed -nE 's/\/(.*)/\1/p' | sed -E 's/favicon.ico//');

if [[ $PARAMETER ]]; then
    echo "redirect.sh: Redirecting $SUBDOMAIN request for $DOMAIN searching for container $PARAMETER"
else
    echo "redirect.sh: Redirecting $SUBDOMAIN request for $DOMAIN searching for container $SUBDOMAIN"
fi

# Subdomain Required for Search
if [[ $SUBDOMAIN ]]; then
    # Divert Local Request
    if [[ $DOMAIN == 'localhost' || $DOMAIN == '127.0.0.1' ]]; then
        # Search Docker & Create Nginx Conf Immediately
        ./createConf.py "SSL_OFF" "$DOMAIN" "$SUBDOMAIN" "$PARAMETER";

        if [ $? -eq 0 ]; then
            restore_output;
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
                    # fcgiwrap is still attached to the stdout/err file on file descriptors 3 & 4
                    # we must close them to start this as a backgroud process
                    ./requestCert.sh "$DOMAIN" "$SUBDOMAIN" "$PARAMETER" 3> /dev/null 4> /dev/null &

                    # If HTTP Config was successful redirect there, otherwise wait for SSL
                    if [[ $STATUS -eq 0 ]]; then
                        restore_output;
                        source searching.sh 5;
                    elif [[ $STATUS -eq 2 ]]; then
                        restore_output;
                        source searching.sh 60;
                    fi
                fi
            fi
        done
    fi
fi

# Return Not Found
restore_output;
source not_found.sh;

# Should never reach this point.
echo -e "Status: 500 Internal Server Error\n"
return 1;
