#!/bin/sh
# Substitute NANOSPARK_PORT in supervisord template and start supervisord.
# Default port 8088; override at runtime with -e NANOSPARK_PORT=3000.
set -e
export NANOSPARK_PORT="${NANOSPARK_PORT:-8088}"
envsubst '${NANOSPARK_PORT}' \
  < /etc/supervisor/conf.d/supervisord.conf.template \
  > /etc/supervisor/conf.d/supervisord.conf
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
