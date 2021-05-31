#!/bin/sh

# Source: https://docs.docker.com/config/containers/multi-service_container/

# Start fcgiwrap process
echo "starting fcgiwrap"
/usr/bin/fcgiwrap -s unix:/var/run/fcgiwrap.sock > /var/log/fcgiwrap/stdout.log 2> /var/log/fcgiwrap/stderr.log &

status=$?
echo "status $status"
if [ $status -ne 0 ]; then
  echo "Failed to start my_first_process: $status"
  exit $status
fi

# Give nginx equal access to socket
echo "waiting on socket"
while [ ! -S /var/run/fcgiwrap.sock ]; do sleep 1; done
chmod 775 /var/run/fcgiwrap.sock;
chgrp nginx /var/run/fcgiwrap.sock;

echo "starting nginx"
# Start nginx process
nginx -g 'daemon off;'

status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start my_second_process: $status"
  exit $status
fi

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

while sleep 60; do
  ps aux |grep my_first_process |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep my_second_process |grep -q -v grep
  PROCESS_2_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    exit 1
  fi
done
