#!/bin/bash

DIR="$1"
PHAR="https://github.com/wp-cli/builds/raw/gh-pages/phar/wp-cli.phar"

# die() comes from here
. /usr/local/bin/libbash

dump_control() {
    cat > DEBIAN/control <<CTRL
Package: php-wpcli
Version: 0.0.0
Architecture: all
Maintainer: Viktor Szépe <viktor@szepe.net>
Section: php
Priority: optional
Depends: php5-cli, php5-mysql | php5-mysqlnd, mysql-client
Homepage: http://wp-cli.org/
Description: wp-cli is a set of command-line tools for managing
 WordPress installations. You can update plugins, set up multisite
 installs and much more, without using a web browser.

CTRL
}

# deb's dir
if ! [ -d "$DIR" ]; then
    mkdir ./php-wpcli || die 1 "cannot create dir here: ${PWD}"
    DIR="php-wpcli"
fi

# should be called php-wpcli as in Debian
[ "$(basename "$DIR")" = php-wpcli ] || die 2 "wrong dirname"

pushd "$DIR"

# control file
if ! [ -r DEBIAN/control ]; then
    mkdir DEBIAN
    dump_control
fi

# content dirs
[ -d usr/bin ] || mkdir -p usr/bin

# download current version
wget -nv -O usr/bin/wp "$PHAR" || die 4 "download failure"
chmod +x usr/bin/wp || die 4 "chmod failure"

# get version
WPCLI_VER="$(grep -ao "define.*WP_CLI_VERSION.*;" usr/bin/wp | cut -d"'" -f4)"
[ -z "$WPCLI_VER" ] && die 5 "cannot get version"
echo "Current version: ${WPCLI_VER}"

# update version
sed -i "s/^Version: .*$/Version: ${WPCLI_VER}/" DEBIAN/control || die 6 "version update failure"

# update MD5-s
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

