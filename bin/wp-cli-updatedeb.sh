#!/bin/bash

DIR="$1"

# die() comes from here
. /usr/local/bin/libbash

dump_control() {
    cat > DEBIAN/control << CTRL
Package: php-wpcli
Version: 0.0.0
Architecture: all
Maintainer: Szépe Viktor <viktor@szepe.net>
Section: php
Priority: optional
Depends: php5-cli, mysql-client, php5-mysql
Homepage: http://wp-cli.org/
Description: wp-cli is a set of command-line tools for managing
 WordPress installations. You can update plugins, set up multisite
 installs and much more, without using a web browser.

CTRL
}

# deb's content dir
[ -d "$DIR" ] || die 1 "no dir"
[ "$(basename "$DIR")" = php-wpcli ] || die 2 "wrong dirname"

pushd "$DIR"

# check dir's content
[ -r DEBIAN/control ] || (mkdir DEBIAN; dump_control)
[ -d usr/bin ] || mkdir -p usr/bin

wget2 -O usr/bin/wp "https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" \
    || die 4 "download failure"

WPCLI_VER="$(grep -a "define.*WP_CLI_VERSION" usr/bin/wp | cut -d"'" -f4)"
[ -z "$WPCLI_VER" ] && die 5 "cannot get version"

sed -i "s/^Version: .*$/Version: ${WPCLI_VER}/" DEBIAN/control || die 6 "version update failure"
find usr -type f -exec md5sum \{\} \; > DEBIAN/md5sums || die 7 "md5sum creation failure"
popd

# build
WPCLI_PKG="${PWD}/php-wpcli_${WPCLI_VER}_all.deb"
fakeroot dpkg-deb --build "$DIR" "$WPCLI_PKG" || die 8 "packaging failure"

# sign it
#dpkg-sig -k 451A4FBA -s builder "$WPCLI_PKG"
# include in the repo
#pushd /var/www/repo.....
#reprepro includedeb wheezy "$WPCLI_PKG"
#popd

