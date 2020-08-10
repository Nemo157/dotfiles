#!/usr/bin/env bash
# Runs a simple oneshot webserver to serve a file on port 6894

if [ -n "$1" ]
then
  echo "Serving file on http://`hostname`:6894/$1"
  { echo -ne "HTTP/1.0 200 OK\r\n\r\n"; cat $1; } | nc -Nl 6894 && echo "File taken"
else
  echo "Usage: one-shot.sh file_to_serve"
  exit 1
fi
