#!/bin/sh

# Source: https://docs.docker.com/config/containers/multi-service_container/

# Make CGI Scripts Exectuable
chmod +x /var/www/default/*.sh /var/www/default/*.py;

# Setup Logging
[[ -d /var/log/autocert ]] || mkdir -p /var/log/autocert;
ln -f -s /dev/stderr /var/log/autocert/stderr.log;
ln -f -s /dev/stdout /var/log/autocert/stdout.log;
export STDERR='/var/log/autocert/stderr.log';
export STDOUT='/var/log/autocert/stdout.log';

# Start fcgiwrap process
echo 'Starting fcgiwrap';
[[ -e /var/run/fcgiwrap.sock ]] && rm /var/run/fcgiwrap.sock;
/usr/bin/fcgiwrap -s unix:/var/run/fcgiwrap.sock &

# Check fcgiwrap start status
status=$?;
echo "fcgiwrap start status: $status";
if [ $status -ne 0 ]; then
  echo "Failed to start fcgiwrap: $status";
  exit $status;
fi

# Wait for fcgiwrap socket
echo 'Waiting for fcgiwrap socket';
while [ ! -S /var/run/fcgiwrap.sock ]; do sleep 1; done

# Give nginx equal access to socket
echo 'Granting nginx access to socket';
chmod 775 /var/run/fcgiwrap.sock;
chgrp nginx /var/run/fcgiwrap.sock;

# Start nginx process
echo 'Starting nginx';
nginx -g 'daemon off;' &

# Check nginx start status
status=$?;
echo "nginx start status: $status";
if [ $status -ne 0 ]; then
  echo "Failed to start nginx: $status";
  kill $(ps aux | grep '/usr/bin/fcgiwrap' | grep -q -v grep | awk '{print $1}');
  rm /var/run/fcgiwrap.sock;
  exit $status;
fi
echo "$0 Executed Successfully. Monitoring processes..";

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds
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
    echo "Process $PROCESS_1 has exited with a status of: $PROCESS_1_STATUS";
    kill $(ps aux | grep "$PROCESS_2" | grep -qv grep | awk '{print $1}');
    rm /var/run/fcgiwrap.sock;
    exit 1;
  elif [ $PROCESS_2_STATUS -ne 0 ]; then
    echo "Process $PROCESS_2 has exited with a status of: $PROCESS_2_STATUS";
    kill $(ps aux | grep "$PROCESS_1" | grep -qv grep | awk '{print $1}');
    rm /var/run/fcgiwrap.sock;
    exit 1;
  fi
done