#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html
# Purpose: Setup Wildcard Certificates for HTTPS Not Found Pages.

# Copy Nginx default.conf
echo "$0: Copying default.conf";
cp /usr/share/nginx/defaults/default.conf /etc/nginx/conf.d/default.conf;

# Check & Setup TLD Wildcard Certificates Options
for TLD in $TLDS; do
  if [ ! "$OPTIONS" ]; then
    OPTIONS="-d $TLD -d *.$TLD";
  else
    OPTIONS="$OPTIONS -d $TLD -d *.$TLD";
  fi
done

if [ -n "$OPTIONS" ]; then
  echo "$0: Configuring Server Name on default.conf";
  SERVER_NAME="*.$(echo $TLDS | sed -e 's/ / *./g')";
  sed -i /etc/nginx/conf.d/default.conf -E -e "s/server_name _;/server_name $SERVER_NAME;/";

  echo "$0: Requesting SSL Certificates for default.conf";
  /usr/share/nginx/scripts/requestSSL.sh --cert-name default $OPTIONS;
  STATUS=$?;
  
  if [ "$STATUS" -eq 0 -a ! $(cat /etc/nginx/conf.d/default.conf | sed -n '/listen 443 ssl/p') ]; then
    echo "$0: Add SSL to default.conf";
    sed -i /etc/nginx/conf.d/default.conf -E \
      -e 's/^([ \t]*)(listen 80;)$/\1\2\n\1listen 443 ssl;/' \
      -e 's/^([ \t]*)(location \/ \{)$/\1include \/etc\/nginx\/ssl.d\/default\/ssl.conf;\n\1\2/';
  fi
else
  echo "$0: No Domains Provided, No Configuration for HTTPS";
  exit 1;
fi

exit 0;
