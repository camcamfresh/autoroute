#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html
# Purpose: Setup Wildcard Certificates for HTTPS Not Found Pages.

# Check & Setup TLD Wildcard Certificates Options
for DOMAIN in $DOMAINS; do
  if [ ! "$OPTIONS" ]; then
    OPTIONS="-d $DOMAIN -d *.$DOMAIN";
  else
    OPTIONS="$OPTIONS -d $DOMAIN -d *.$DOMAIN";
  fi
done

if [ -n "$OPTIONS" ]; then
    /usr/share/nginx/scripts/requestSSL.sh --cert-name default $OPTIONS;
else
    echo "init.sh: No Domains Provided, skipping Not Found Page for HTTPS";
    exit 1;
fi

if [ ! -n $(cat /etc/nginx/conf.d/default.conf | sed -n '/listen 443 ssl/p') ]; then
    sed -i /etc/nginx/conf.d/default.conf -E \
      -e 's/^([ \t]*)(listen 80;)$/\1\2\n\1listen 443 ssl;/' \
      -e 's/^([ \t]*)(location \/ \{)$/\1include \/etc\/nginx\/ssl.d\/default\/ssl.conf;\n\1\2/';
fi

if [ $(ps aux | grep "$nginx: master process" | grep -qv grep) -eq 0 ]; then
    nginx -s reload
fi

exit 0;
