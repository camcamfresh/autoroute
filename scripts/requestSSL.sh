#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html
# Source : https://docs.docker.com/config/containers/multi-service_container/

if [ ! -e '/cert/autocert.sock' ]; then
    echo "$0: /cert/autocert.sock not detected, cannot request SSL generation." > /dev/stderr;
    exit 1;
elif [ ! -d '/cert' ]; then
    echo "$0: cannot access /cert directory, discarding SSL generation request." > /dev/stderr;
    exit 1;
fi

CERT_NAME='';
DOMAINS='';
OPTIONS='';
READ_NEXT=0;
for ARG in $@; do
    case "$ARG" in
        '--cert-name')
            READ_NEXT=1;;
        '--domain'|'--domains'|'-d')
            READ_NEXT=2;;
        *)
            if [ $READ_NEXT -eq 1 ]; then
                CERT_NAME="$ARG";
            elif [ $READ_NEXT -eq 2 ]; then
                if [ -n "$DOMAINS" ]; then
                    DOMAINS="$DOMAINS,$ARG";
                else
                    DOMAINS="$ARG";
                fi
            else
                if [ ! "$OPTIONS" ]; then
                    OPTIONS="$ARG";
                else
                    OPTIONS="$OPTIONS $ARG";
                fi
            fi
            READ_NEXT=0;
    esac
done

if [ -n "$DOMAINS" ]; then
    if [ ! "$CERT_NAME" ]; then
        CERT_NAME=$(echo $DOMAINS | sed 's|(.*)(,.+)?|\1|');
    fi
    OPTIONS="$OPTIONS --domains $DOMAINS";
fi

# Request Certificate via autocert socket
echo "$0: Requesting Certificate for $CERT_NAME";
echo "autocert.sh certonly $OPTIONS" | socat unix-client:/cert/autocert.sock stdin;

# Wait for Certificates
STEPS=0;
while sleep 10; do
    if [ -d "/cert/$CERT_NAME/" ]; then
        echo "$0: Successfully Generated Requested SSL Certificates";
        break;
    fi

    if [ "$STEPS" -eq 6 ]; then
        echo "$0: Waited 60 seconds and did not detect SSL certificates." > /dev/stderr;
        exit 1;
    else
        STEPS=$(($STEPS+1));
    fi
done

echo "$0: Creating Nginx Certificate File";
[[ -d /etc/nginx/ssl.d/$CERT_NAME ]] || mkdir -p /etc/nginx/ssl.d/$CERT_NAME/;
if [[ "$CERT_NAME" == "default" ]]; then
    cat /usr/share/nginx/defaults/ssl.conf | sed -e '1s/{SERVER_NAME}/_/' -e 's/{SERVER_NAME}/default/g' > /etc/nginx/ssl.d/default/ssl.conf;
else
    cat /usr/share/nginx/defaults/ssl.conf | sed "s/{SERVER_NAME}/$CERT_NAME/g" > /etc/nginx/ssl.d/$CERT_NAME/ssl.conf;
fi

cp "/cert/$CERT_NAME/fullchain.pem" "/etc/nginx/ssl.d/$CERT_NAME/fullchain.pem";
cp "/cert/$CERT_NAME/privkey.pem" "/etc/nginx/ssl.d/$CERT_NAME/privkey.pem";
exit 0;
