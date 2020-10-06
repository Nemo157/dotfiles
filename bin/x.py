#!/bin/sh

cd "$(git rev-parse --show-toplevel)"
./x.py "$@"
