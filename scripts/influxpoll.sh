#!/bin/bash

PIDFILE=/var/run/influxpoll.pid

case "$1" in 
start)
   if [ -e $PIDFILE ]; then
   echo influxpoll.sh is already running, pid=`cat $PIDFILE`
   else
   /home/tbauer516/docker/poll.sh >/dev/null 2>&1 < /dev/null &
   echo $!>$PIDFILE
   fi
   ;;
stop)
   kill `cat $PIDFILE`
   rm $PIDFILE
   ;;
restart)
   $0 stop
   $0 start
   ;;
status)
   if [ -e $PIDFILE ]; then
      echo influxpoll.sh is running, pid=`cat $PIDFILE`
   else
      echo influxpoll.sh is NOT running
      exit 1
   fi
   ;;
*)
   echo "Usage: $0 {start|stop|status|restart}"
esac

exit 0 
