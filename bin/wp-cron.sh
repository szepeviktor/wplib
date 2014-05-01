#!/bin/bash


WPCRON_PATH="server/wp-cron.php"


DIR="$1"
[ -d "$DIR" ] || exit 1

## server data

export REMOTE_ADDR="127.0.0.1"
#export SERVER_ADDR="127.0.0.1"
#export SERVER_SOFTWARE="Apache"
#export SERVER_NAME="<domain.net>"

## request data

## GET / HTTP/1.1
export REQUEST_METHOD="GET"
#export REQUEST_URI="/"
#export SERVER_PROTOCOL="HTTP/1.1"

## Host: <domain.net:port>
## User-Agent: Mozilla/5.0 ...
#export HTTP_HOST=""
export HTTP_USER_AGENT="php-cli"

##################################

pushd "$DIR" > /dev/null || exit 2

[ -r "${WPCRON_PATH}" ] || exit 3
/usr/bin/php "${WPCRON_PATH}" || echo "[wp-cron] PHP error: $?, ${PWD}" >&2

popd > /dev/null

## wp-config.php:
## define('DISABLE_WP_CRON', true);
