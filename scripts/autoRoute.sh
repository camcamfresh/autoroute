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
	echo "$SUBDOMAIN" >> ./temp_exclude.dat;
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
		./createRoute.py "$DOMAIN" "$SUBDOMAIN";
		sed -i -e "/^$SUBDOMAIN$/d" ./temp_exclude.dat
	) 3> /dev/null 4>&3 &
	# Returning file descriptors must be detached for subprocess to function asynchronously.
}

is_domain() {
	for TLD_DOMAIN in $DOMAINS; do
		if [ "$TLD_DOMAIN" = "$DOMAIN" ]; then
			return 0;
		fi
	done
	return 1;
}

is_excluded() {
	EXCLUDE="$(cat ./temp_exclude.dat 2> /dev/null | tr -s '\n' ' ')";
	for EXCLUSION in $EXCLUDE; do
		if [ "$EXCLUSION" = "$SUBDOMAIN" ]; then
			return 0;
		fi
	done
	return 1;
}

#Process Request
if is_domain && ! is_excluded; then
	echo "autoRoute.sh: Domain match found!";
	./createRoute.py "$DOMAIN" "$SUBDOMAIN";
	STATUS=$?;

	if [ "$STATUS" -eq 0 ]; then
		request_ssl;
		return_searching 30;
	elif [ "$STATUS" -eq 1 ]; then
		request_ssl;
		return_searching 60;
	fi
fi

return_not_found;
