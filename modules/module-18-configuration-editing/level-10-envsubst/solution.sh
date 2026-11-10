#!/bin/bash
# Export the values, then give envsubst the list of variables it may touch.
set -a
. ./deploy.env
set +a
envsubst '$APP_HOST $APP_PORT' < nginx.conf.tmpl > nginx.conf
cat nginx.conf
