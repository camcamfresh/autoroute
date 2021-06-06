#!/bin/sh
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html
# Source : https://docs.docker.com/config/containers/multi-service_container/

# Create Kill Process Function
kill_process() {
	kill $(ps aux | grep "$1" | grep -qv grep | awk '{print $1}');
	[[ -e /var/run/fcgiwrap.sock ]] && rm /var/run/fcgiwrap.sock;
	exit 1;
}

# Setup Logging
echo 'Setting up autocert logging';
[[ -d /var/log/autocert ]] || mkdir -p /var/log/autocert;
ln -fs "/proc/$$/fd/1" /var/log/autocert/stdout.log;
ln -fs "/proc/$$/fd/2" /var/log/autocert/stderr.log;

# Setup & Start fcgiwrap
echo 'Setting up & Starting fcgiwrap process';
chmod +x /usr/share/nginx/scripts/*;
[[ -e /var/run/fcgiwrap.sock ]] && rm /var/run/fcgiwrap.sock;
/usr/bin/fcgiwrap -s unix:/var/run/fcgiwrap.sock &

# Check Start Status
STATUS=$?
echo "fcgiwrap start status: $STATUS";
if [ $STATUS -ne 0 ]; then
	echo 'Failed to start fgciwrap' > /dev/stderr;
	exit $STATUS;
fi

# Wait for fcgiwrap socket
echo 'Waiting for fcgiwrap socket';
while [ ! -S /var/run/fcgiwrap.sock ]; do sleep 1; done

# Setup & Start nginx
echo 'Granting nginx access to socket';
chmod 775 /var/run/fcgiwrap.sock;
chgrp nginx /var/run/fcgiwrap.sock;

echo 'Starting nginx';
nginx -g 'daemon off;' &

# Check Start Status
STATUS=$?;
echo "nginx start status: $STATUS";
if [ $STATUS -ne 0 ]; then
  echo 'Failed to start nginx' > /dev/stderr;
  kill_process '/usr/bin/fcgiwrap';
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
  
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 ]; then
    echo "Process $PROCESS_1 has exited with a status of: $PROCESS_1_STATUS" > /dev/stderr;
  	kill_process "$PROCESS_2";
  elif [ $PROCESS_2_STATUS -ne 0 ]; then
    echo "Process $PROCESS_2 has exited with a status of: $PROCESS_2_STATUS" > /dev/stderr;
    kill_process "$PROCESS_1";
  fi
done
