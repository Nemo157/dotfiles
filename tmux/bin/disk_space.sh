#!/bin/sh

df -Hln | tail +2 | awk 'int($5) > 90 { print " "$9" has "$4" free" }'
