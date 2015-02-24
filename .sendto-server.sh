#!/bin/bash

ARC="wplib-szerver.tar.gz"

rm $ARC

tar czvf $ARC \
    /usr/local/share/wplib \
    /usr/local/bin/libbash \
    /usr/local/bin/wp-cli-updatedeb.sh \
    /usr/local/bin/wp-cli-updatever.php \
    /usr/local/bin/wp-cron.sh \
    /usr/local/bin/wp-lib.sh

# https://github.com/szepeviktor/debian-server-tools/blob/master/backup/pipe.sh
pipe.sh put $ARC
