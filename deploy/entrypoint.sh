#!/bin/sh
# Substitute PORT in supervisord template and start supervisord.
# Render assigns PORT dynamically at runtime.
set -e
export PORT="${PORT:-10000}"
export NANOSPARK_PORT="${PORT}"
envsubst '${PORT}' \
  < /etc/supervisor/conf.d/supervisord.conf.template \
  > /etc/supervisor/conf.d/supervisord.conf
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
