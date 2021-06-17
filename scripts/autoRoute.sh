#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html

# This script is executed by fcgiwrap which monitors both
# stdin & stdout when returning output to a request.
# To enable proper logging, the file descriptors are changed until a response is ready.
exec 3<&1 4<&2 1<> /var/log/autoroute/stdout.log 2<> /var/log/autoroute/stderr.log;
restore_output() {
	exec 1<&- 2<&- 1<&3 2<&4;
}

# Return Pages
return_not_found() {
	restore_output;
	echo -e 'Status: 404 Not Found\n';
	cat ../defaults/not_found.html;
	exit 0;
}

return_searching() {
	restore_output;
	echo -e 'Status: 307 Temporary Redirect\n';
	cat ../defaults/searching.html | sed -e "s/{TIMEOUT}/$1/g";
	exit 0;
}

#Parse Request
echo "autoRoute.sh: Routing $HTTP_HOST";
DOMAIN=$(echo "$HTTP_HOST" | sed -nE 's/(.*\.)?([^\.]+\.(com|org|net))([:?\/].*)?/\2/p' | tr '[:upper:]' '[:lower:]');
SUBDOMAIN=$(echo "$HTTP_HOST" | sed -nE "s/(.*)[.]$DOMAIN.*/\1/p" | tr '[:upper:]' '[:lower:]');

# Create Request SSL Function
request_ssl() {
	(
		./requestSSL.sh "-d $SUBDOMAIN.$DOMAIN" &&\
		./createRoute.py "$DOMAIN" "$SUBDOMAIN"
	) 3> /dev/null 4>&3 &
}

#Process Request
for ALLOWED_DOMAIN in $DOMAINS; do
	if [ "$ALLOWED_DOMAIN" = "$DOMAIN" ]; then
		echo "autoRoute.sh: Domain match found!";
		./createRoute.py "$DOMAIN" "$SUBDOMAIN";
		STATUS=$?;

		if [ "$STATUS" -eq 0 ]; then
			request_ssl;
			return_searching 5;
		elif [ "$STATUS" -eq 1 ]; then
			request_ssl;			
			return_searching 60;
		else
			break;
		fi
	fi
done

return_not_found;
