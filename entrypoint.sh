#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html
# Source : https://docs.docker.com/config/containers/multi-service_container/

# Setup Logging
echo 'entrypoint.sh: Setting up logging';
[[ -d /var/log/autoroute ]] || mkdir -p /var/log/autoroute;
ln -fs "/proc/$$/fd/1" /var/log/autoroute/stdout.log;
ln -fs "/proc/$$/fd/2" /var/log/autoroute/stderr.log;

/usr/share/nginx/scripts/init.sh &

# Kill process group when this process dies.
trap 'rm -f /var/run/fcgiwrap.sock; trap - SIGTERM && kill 0' EXIT KILL SIGINT SIGTERM ;

# Start fcgiwrap
echo 'entrypoint.sh: Starting fcgiwrap';
[[ -e /var/run/fcgiwrap.sock ]] && rm /var/run/fcgiwrap.sock;
/usr/bin/fcgiwrap -s unix:/var/run/fcgiwrap.sock &

# Check Start Status
STATUS=$?
echo "entrypoint.sh: fcgiwrap start status: $STATUS";
if [ $STATUS -ne 0 ]; then
	echo 'entrypoint.sh: Failed to start fgciwrap' > /dev/stderr;
	exit $STATUS;
fi

# Wait for fcgiwrap socket
echo 'entrypoint.sh: Waiting for fcgiwrap socket';
while [ ! -S /var/run/fcgiwrap.sock ]; do sleep 1; done

# Grant nginx to fcgiwrap socket
echo 'entrypoint.sh: Granting nginx access to socket';
chmod 775 /var/run/fcgiwrap.sock;
chgrp nginx /var/run/fcgiwrap.sock;

# Start nginx
echo 'entrypoint.sh: Starting nginx';
nginx -g 'daemon off;' &

# Check Start Status
STATUS=$?;
echo "entrypoint.sh: nginx start status: $STATUS";
if [ $STATUS -ne 0 ]; then
  echo 'entrypoint.sh: Failed to start nginx' > /dev/stderr;
  exit $STATUS;
fi

# Naive Monitoring
echo "$0 Executed Successfully. Monitoring processes..";
PROCESS_1='/usr/bin/fcgiwrap';
PROCESS_2='nginx: master process';

while sleep 60; do
  ps aux | grep "$PROCESS_1" | grep -q -v grep;
  PROCESS_1_STATUS=$?;
  ps aux | grep "$PROCESS_2" | grep -q -v grep;
  PROCESS_2_STATUS=$?;
  
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 ]; then
    echo "entrypoint.sh: Process $PROCESS_1 has exited with a status of: $PROCESS_1_STATUS" > /dev/stderr;
  	exit $PROCESS_1_STATUS;
  elif [ $PROCESS_2_STATUS -ne 0 ]; then
    echo "entrypoint.sh: Process $PROCESS_2 has exited with a status of: $PROCESS_2_STATUS" > /dev/stderr;
    exit $PROCESS_2_STATUS;
  fi
done
