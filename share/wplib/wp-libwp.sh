#!/bin/bash

## set WPLIB_PROFILE to "1" to get execution profiling values


. /usr/local/bin/libbash

WPLIBROOT="/usr/local/share/wplib"
OPCACHEDEL="${WPLIBROOT}/opcache-del-dir.php"
ROBOTSUPDATES="${WPLIBROOT}/wp-robots-update.php"


## set terminal color constants
## sets: several terminal color constants
function term_colors() {
    black="$(tput setaf 0)"
    red="$(tput setaf 1)"
    green="$(tput setaf 2)"
    yellow="$(tput setaf 3)"
    blue="$(tput setaf 4)"
    magenta="$(tput setaf 5)"
    cyan="$(tput setaf 6)"
    white="$(tput setaf 7)"

    blackBG="$(tput setab 0)"
    redBG="$(tput setab 1)"
    greenBG="$(tput setab 2)"
    yellowBG="$(tput setab 3)"
    blueBG="$(tput setab 4)"
    magentaBG="$(tput setab 5)"
    cyanBG="$(tput setab 6)"
    whiteBG="$(tput setab 7)"

    bold="$(tput bold)"
    boldEND="$(tput dim)"
    bright="$(tput bold)"
    brightEND="$(tput dim)"
    underline="$(tput smul)"
    underlineEND="$(tput rmul)"
    reverse="$(tput rev)"
    reset="$(tput sgr0)"
}

## simple echo
wp_log___() {
    echo -e "$*"
}

## echo "wp" prepended in blue background without EOL
wp_log__() {
    echo -ne "${reset}${blueBG}${white}[wp]${reset} $*"
}

## echo with "wp" and with EOL
wp_log() {
    wp_log__ "$*"; echo
}

## echo "wp" prepended in red background
wp_error() {
    echo -e "${reset}${bold}${redBG}${white}[wp]${reset} $*"
}

## set WPROOT global to current dir
## sets: WPROOT
set_root() {
    WPROOT="$(pwd)"
    #ls "$WPROOT" > /dev/null 2>&1 || die 99 "no permission to list: ${WPROOT}"
    #(pushd "$WPROOT" > /dev/null 2>&1; popd > /dev/null 2>&1) || die 99 "no permission to enter: ${WPROOT}"
}

## get owner of the WP root directory
## sets: WPOWNER, WPGROUP
get_owner() {
    set_root
    WPOWNER="$(stat -c "%U" "$WPROOT")"
    WPGROUP="$(stat -c "%G" "$WPROOT")"
    [ -z "$WPOWNER" ] && die 1 "no owner"
    grep -q "^${WPOWNER}:" /etc/passwd || die 2 "owner does not exist"
}

## call wp-cli with sudo
do_wp__() {
    local RET
    [ -z "$WPLIB_PROFILE" ] || WPLIB_PSTART="$(date "+%s.%N")"
    sudo -u "$WPOWNER" -- /bin/bash -c "cd \"$WPROOT\"; wp \"\$@\"" wp "$@"
    RET=$?
    [ -z "$WPLIB_PROFILE" ] || (echo -n "${reset}${greenBG}${black}[wp]${reset} $*: ";
        echo "scale=3; $(date "+%s.%N")-${WPLIB_PSTART};" | bc -q) >&2
    return "$RET"
}

## check WPOWNER and WPROOT for wp-cli and sudo
do_wp() {
    php -r 'exit((extension_loaded("suhosin") && strpos(ini_get("suhosin.executor.include.whitelist"), "phar") !== false )?0:1);' \
        || die 99 "suhosin whitelist"
    which wp > /dev/null || die 99 "no wp-cli"
    [ -z "$WPOWNER" ] && die 97 "owner empty"
    [ -z "$WPROOT" ] && die 96 "wp root not set"
    do_wp__ "$@"
}

## is WP installed?
detect_wp() {
    # this set WPROOT also
    get_owner
    if ! grep -q "debug: true" "${WPROOT}/wp-cli.yml" 2> /dev/null \
        && ! grep -q "debug: true" "$(dirname "$WPROOT")/wp-cli.yml" 2> /dev/null; then
        return 3 # no wp-cli FIXME -> check wp-cli troughoutly
    fi

    do_wp core is-installed # "no wp"
}

## PHP errors while running wp-cli
detect_php_errors() {
    get_owner
    grep -q "debug: true" wp-cli.yml || return 3

    exec 3>/dev/null
    do_wp option get siteurl 2>&1 1>&3 | grep "PHP " && return 101
    do_wp eval 'echo 1;' 2>&1 1>&3 | grep "PHP " && return 102
    exec 3>&-
}

## recursive chown to fix file permissions
revert_permissions() {
    detect_wp || return 1
    wp_log "owner=${WPOWNER}"

    wp_log "reverting permissions..."
    chown -Rc ${WPOWNER}:${WPOWNER} "$WPROOT" #|| die 7 "chown error!"
}

## clear this WPROOT from opcode cache
## needs: external php file
clear_cache() {
    wp_log__ "opcode cache clearing reply: '"
    php "$OPCACHEDEL" "$WPROOT"
    local RET=$?
    wp_log___ "', exit code: ${RET}" # missing EOL
}

## update WP core, database and clear opcache
update_core() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"
    #FIXME do_wp core update --force --version="$VERSION" ??? || return 4 #"core update error!"
    do_wp core update --force || return 4 #"core update error!"
    do_wp core update-db || return 5 #"db update error!"
    clear_cache
}

## update PC-Robots plugin's settings
do_robots() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"
#    local ACTIVE="$(do_wp plugin list --field=status --name=pc-robotstxt 2> /dev/null)"
#
#    if [ "$ACTIVE" != active ]
#    then
#        wp_log "no PC-Robots plugin"
#        return 2
#    fi
## in ROBOTSUPDATES php: `if (false === is_plugin_active('pc-robotstxt/pc-robotstxt.php')) die(10);`

    do_wp eval-file "$ROBOTSUPDATES"
}

## hide metaboxes from iThemes Security's admin pages
## param: user
itsec_screen() {
    local USER="$1"
    local ITSEC_EVERY_PAGE='"itsec_security_updates","itsec_need_help","itsec_get_backup","itsec_sync_integration"'

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"
    do_wp user get "$USER" > /dev/null || return 1

    do_wp__ user meta delete "$USER" metaboxhidden_toplevel_page_itsec
    do_wp__ user meta delete "$USER" metaboxhidden_security_page_toplevel_page_itsec_settings
    do_wp__ user meta delete "$USER" metaboxhidden_security_page_toplevel_page_itsec_advanced
    do_wp__ user meta delete "$USER" metaboxhidden_security_page_toplevel_page_itsec_backups
    do_wp__ user meta delete "$USER" metaboxhidden_security_page_toplevel_page_itsec_logs
    do_wp__ user meta delete "$USER" screen_layout_security_page_toplevel_page_itsec_logs

    do_wp__ user meta update "$USER" metaboxhidden_toplevel_page_itsec \
        '["itsec_get_started",'"$ITSEC_EVERY_PAGE"']' --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_settings \
        '["ssl_options",'"$ITSEC_EVERY_PAGE"']' --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_advanced \
        '["advanced_intro",'"$ITSEC_EVERY_PAGE"']' --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_backups \
        '["backup_description","backupbuddy_info",'"$ITSEC_EVERY_PAGE"']' --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_logs \
        '["itsec_log_header",'"$ITSEC_EVERY_PAGE"']' --format=json
    do_wp__ user meta update "$USER" screen_layout_security_page_toplevel_page_itsec_logs \
        '"1"' --format=json
}

## show plugin changelog in elinks console browser
## param: plugin name
plugin_changelog() {
    which elinks > /dev/null || return 1 # "no elinks"

    local PLUGIN="$1"
    [ -z "$PLUGIN" ] && return 2 # no plugin name

    wget --quiet --output-document=- "http://api.wordpress.org/plugins/info/1.0/${PLUGIN}" \
        | php -r '$seri=unserialize(stream_get_contents(STDIN));echo "<h1>$seri->name</h1>".$seri->sections["changelog"];' \
        | elinks -force-html
}

## backup a plugin
## param: plugin name
## param: plugin version
## param: plugin dir
plugin_backup__() {
    local PLUGIN="$1"
    local CURRENT="$2"
    local PLUGINDIR="$3"
    [ -z "${PLUGIN}${CURRENT}" ] && return 1 # no name or version
    [ -d "$PLUGINDIR" ] || return 2 # not valid dir

    local BCKDIR=~/wplib-bck
    local SITEURL="$(do_wp__ option get siteurl 2> /dev/null)"
    local SITENAME="${SITEURL#*//}"
    ## backup file name="wplib-bck + sitename + today + plugin name_version"
    local BCK="${BCKDIR}/${SITENAME//[^a-z0-9]}-$(LC_ALL=C date "+%Y%m%d")-${PLUGIN}_${CURRENT}.tar.xz"

    wp_log "backing up: ${PLUGIN}"
    if ! mkdir -p "$BCKDIR"; then
        wp_error "cannot create dir: '${BCKDIR}'"
        return 3
    fi
    #no need --absolute-names
    tar --create --xz --directory "$(dirname "$PLUGINDIR")" --file "$BCK" "$(basename "$PLUGINDIR")"
}

## backup a plugin
## param: plugin name
plugin_backup() {
    local PLUGIN="$1"

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    [ -z "$PLUGIN" ] && return 2 # no name

    local PLUGINDIR="$(do_wp plugin path "$PLUGIN" --dir 2> /dev/null)"
    if ! [ -d "$PLUGINDIR" ]; then
        wp_error "no dir: '${PLUGIN}'"
        return 2
    fi
    local CURRENT="$(do_wp__ plugin list --name="$PLUGIN" --fields=version 2> /dev/null | tail -n +2)"

    plugin_backup__ "$PLUGIN" "$CURRENT" "$PLUGINDIR"
}

## update plugins with minor update + backup
## param: update only with same second version number
plugin_minor_updates() {
    local SECOND="$1"

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    do_wp plugin list --update=available --fields=name,version,update_version | tail -n +2 \
        | while read PLUGINDATA; do
            local PLUGIN="$(echo "$PLUGINDATA" | cut -f1)"
            local CURRENT="$(echo "$PLUGINDATA" | cut -f2)"
            CURRENT="${CURRENT#v}"
            local UPDATE="$(echo "$PLUGINDATA" | cut -f3)"
            UPDATE="${UPDATE#v}"
            local IFS="."
            local CURRENT=($CURRENT)
            local UPDATE=($UPDATE)

            # check digits
            if ! [ -z "${UPDATE[0]//[0-9]}" ] || ! [ -z "${CURRENT[0]//[0-9]}" ] \
                || ! [ -z "${UPDATE[1]//[0-9]}" ] || ! [ -z "${CURRENT[1]//[0-9]}" ]; then
                wp_error "${CURRENT[*]} or ${UPDATE[*]} is not a version number"
                continue
            fi

            # major version number diff
            # OR second version number diff
            if [ "${UPDATE[0]}" != "${CURRENT[0]}" ] \
                || ([ "$SECOND" = "--second" ] && [ "${UPDATE[1]}" != "${CURRENT[1]}" ]); then
                plugin_changelog "$PLUGIN"
                continue
            fi

            ## backup
            local PLUGINDIR="$(do_wp__ plugin path "$PLUGIN" --dir 2> /dev/null)"
            if ! [ -d "$PLUGINDIR" ]; then
                wp_error "dir problem: ${PLUGIN}"
                continue
            fi
            wp_log "updating ${PLUGIN}"
            plugin_backup__ "$PLUGIN" "$CURRENT" "$PLUGINDIR" || wp_error "backup failure: ${PLUGIN}"

            do_wp__ plugin update "$PLUGIN" || wp_error "plugin update failed"
        done
    clear_cache
}

## updates all plugins with backup (for modified plugins)
plugin_update_backup() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    do_wp plugin list --update=available --fields=name,version | tail -n +2 \
        | while read PLUGINDATA; do
            local PLUGIN="$(echo "$PLUGINDATA" | cut -f1)"
            local CURRENT="$(echo "$PLUGINDATA" | cut -f2)"

            ## backup
            local PLUGINDIR="$(do_wp__ plugin path "$PLUGIN" --dir 2> /dev/null)"
            if ! [ -d "$PLUGINDIR" ]; then
                wp_error "dir problem: ${PLUGIN}"
                continue
            fi
            wp_log "updating ${PLUGIN}"
            plugin_backup__ "$PLUGIN" "$CURRENT" "$PLUGINDIR" || wp_error "backup failure: ${PLUGIN}"

            do_wp__ plugin update "$PLUGIN" || wp_error "plugin update failed"
        done
}

## update all plugin except the listed ones + backup
## params: plugins to exclude
plugin_update_except() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    local EXCEPTIONS=($@)
    do_wp plugin list --update=available --fields=name,version | tail -n +2 \
        | while read PLUGINDATA; do
            local PLUGIN="$(echo "$PLUGINDATA" | cut -f1)"
            local CURRENT="$(echo "$PLUGINDATA" | cut -f2)"

            if inset "$PLUGIN" ${EXCEPTIONS[*]}; then
                wp_log "not updated: ${PLUGIN}"
                continue
            fi

            ## backup
            local PLUGINDIR="$(do_wp__ plugin path "$PLUGIN" --dir 2> /dev/null)"
            if ! [ -d "$PLUGINDIR" ]; then
                wp_error "dir problem: ${PLUGIN}"
                continue
            fi
            wp_log "updating ${PLUGIN}"
            plugin_backup__ "$PLUGIN" "$CURRENT" "$PLUGINDIR" || wp_error "backup failure: ${PLUGIN}"

            do_wp__ plugin update "$PLUGIN" || wp_error "plugin update failed"
        done
    clear_cache
}

## find wp-config.php
## sets: WPCONFIG
find_wpconfig(){
    # normal
    [ -f "${WPROOT}/wp-config.php" ] && WPCONFIG="${WPROOT}/wp-config.php"
    # above
    [ -f "$(dirname "$WPROOT")/wp-config.php" ] && WPCONFIG="$(dirname "$WPROOT")/wp-config.php"
    # secret
    [ -f "${WPROOT}/${SECRET_DIR_NAME}/wp-config.php" ] && WPCONFIG="${WPROOT}/${SECRET_DIR_NAME}/wp-config.php"

    ! [ -z "$WPCONFIG" ] || return 1
}

## checks defines in wp-config.php, displays found and suggested
check_wpconfig(){
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    find_wpconfig || return 2 # no wp-config

    for DEFINE in WPLANG WP_DEBUG WP_MAX_MEMORY_LIMIT WP_POST_REVISIONS WP_CACHE \
        DISABLE_WP_CRON AUTOMATIC_UPDATER_DISABLED DISALLOW_FILE_EDIT \
        ITSEC_FILE_CHECK_CRON WP_USE_EXT_MYSQL; do
        if ! grep --color -Hn "define.*${DEFINE}" "$WPCONFIG"; then
            case "$DEFINE" in
                WPLANG)
                    wp_error "define( 'WPLANG', 'hu_HU' );"
                ;;
                WP_DEBUG)
                    wp_error "define( 'WP_DEBUG', false );"
                ;;
                WP_MAX_MEMORY_LIMIT)
                    wp_error "define( 'WP_MAX_MEMORY_LIMIT', '127M' );"
                ;;
                WP_POST_REVISIONS)
                    wp_error "define( 'WP_POST_REVISIONS', 10 );"
                ;;
                WP_CACHE)
                    wp_error "define( 'WP_CACHE', true );"
                ;;
                DISABLE_WP_CRON)
                    wp_error "define( 'DISABLE_WP_CRON', true );"
                ;;
                AUTOMATIC_UPDATER_DISABLED)
                    wp_error "define( 'AUTOMATIC_UPDATER_DISABLED', true );"
                ;;
                DISALLOW_FILE_EDIT)
                    wp_error "define( 'DISALLOW_FILE_EDIT', true );"
                ;;
                ITSEC_FILE_CHECK_CRON)
                    wp_error "define( 'ITSEC_FILE_CHECK_CRON', true );"
                ;;
                WP_USE_EXT_MYSQL)
                    wp_error "define( 'WP_USE_EXT_MYSQL', false );"
                ;;
            esac
        fi
    done
}

## mount wp-content/cache to ramdisk (tmpfs)
## params: size of ramdisk in megabytes
mount_cache() {
    # FIXME run from sudo and skip chown?
    SIZE="$1"

    [ -z "$SIZE" ] && return 1 # no size
    [ -z "${SIZE//[0-9]}" ] || return 2 # digits only

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}, group=${WPGROUP}"

    local WPCONTENTDIR="$(do_wp__ eval 'echo WP_CONTENT_DIR;' 2> /dev/null)"
    [ -d "$WPCONTENTDIR" ] || return 2 # "no wp-content"
    local CACHEDIR="${WPCONTENTDIR}/cache"
    local CACHETEMPDIR="${WPCONTENTDIR}/cache-temp"

    # check user
    [ "$(id -u)" = 0 ] || die 100 "only root can mount cache"

    # already mounted?
    mount | grep -q "on ${CACHEDIR} " && return 3 # "already mounted"

    # move existing disk cache to a temporary directory
    [ -d "$CACHETEMPDIR" ] && return 4 # "cache-temp exists"
    if [ -d "$CACHEDIR" ]
    then
        local CURRENTSIZE="$(du -bs "$CACHEDIR" | cut -f1)"
        # requested size must be at least 1.5×current size
        [ "$(echo "${SIZE}*1024*1024/1" | bc -q)" -lt "$(echo "${CURRENTSIZE}*1.5/1" | bc -q)" ] && return 5 # "SIZE is too small"
        wp_log "moving current cache to temp"
        mv "$CACHEDIR" "$CACHETEMPDIR" || return 6 # "disk cache move failure"
    fi

    # create cache in RAM
    mkdir "$CACHEDIR" || return 7 # "cannot create new cache directory"
    chown ${WPOWNER}:${WPGROUP} "$CACHEDIR" || return 7 # "cannot set owner"
#no size    mount -t tmpfs -o size=${SIZE}m,uid=${WPOWNER},gid=${WPGROUP},mode=755 tmpfs "$CACHEDIR" || return 8 # "cannot mount ramdisk"
    mount -t tmpfs -o uid=${WPOWNER},gid=${WPGROUP},mode=755 tmpfs "$CACHEDIR" || return 8 # "cannot mount ramdisk"

    # move files back to ramdisk
    if [ -d "$CACHETEMPDIR" ]
    then
        if ls "$CACHETEMPDIR"/* > /dev/null 2>&1; then
            wp_log "moving files back to cache"
            mv "$CACHETEMPDIR"/* "$CACHEDIR" || return 9 # "cannot move back to ramdisk"
        fi
        rmdir "$CACHETEMPDIR" || return 10 # "cannot remove cache-temp"
    fi
}

## un-mount wp-content/cache
umount_cache() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}, group=${WPGROUP}"

    local WPCONTENTDIR="$(do_wp__ eval 'echo WP_CONTENT_DIR;' 2> /dev/null)"
    local CACHEDIR="${WPCONTENTDIR}/cache"
    local CACHETEMPDIR="${WPCONTENTDIR}/cache-temp"

    # check user
    [ "$(id -u)" = 0 ] || die 100 "only root can mount cache"
    # FIXME if it's in fstab, the owner can mount it

    # already mounted?
    mount | grep -q "on ${CACHEDIR} " || return 1 # "not mounted"

    # copy existing ramdisk cache to a temporary directory
    # cache dir must exist, it is mounted
    [ -d "$CACHETEMPDIR" ] && return 3 # "cache-temp already exists"
    cp -a "$CACHEDIR" "$CACHETEMPDIR" || return 5 # "ramdisk cache copy failure"

    # umount ramdisk
    umount "$CACHEDIR" || return 6 # "cannot umount ramdisk"

    # delete original disk cache hidden behind tmpfs mount
    rm -rf "$CACHEDIR" || return 7 # "cannot remove original cache directory"

    # rename temp to cache
    mv "$CACHETEMPDIR" "$CACHEDIR" || return 10 # "cannot move to new cache directory"
}

## check YAML file
check_yaml() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    local WPYML="${WPROOT}/wp-cli.yml"

    for OPTION in url user debug skip-plugins; do
        if ! grep --color -Hn "^${OPTION}:" "$WPYML"; then
            case "$OPTION" in
                url)
                    wp_error "url: $(do_wp__ option get siteurl 2> /dev/null)"
                ;;
                user)
                    wp_error "user: $(do_wp__ user list --field=user_login \
                        --role=administrator --orderby=ID --number=1 2> /dev/null )"
                ;;
                debug)
                    wp_error "debug: true"
                ;;
                skip-plugins)
                    wp_error "skip-plugins: better-wp-security"
                ;;
            esac
        fi
    done

    # two deep options
    for OPTION2 in "core update|locale"; do
        if ! (grep --color -Hn -A1 "^${OPTION2%|*}:" "$WPYML" \
            && grep -A1 "^${OPTION2%|*}:" "$WPYML" | grep -q "^\s*${OPTION2#*|}:"); then
            case "$OPTION2" in
                "core update|locale")
                    wp_error "core update:\n    locale: $(do_wp__ eval 'global $locale; echo $locale;' 2> /dev/null)"
                ;;
            esac
        fi
    done
}

## full setup of a new site
full_setup() {

    local WPLIBCONF=~/.config/wplib/wplibrc
    local WPSECRET="$1"
    local YAML_PATH

    if detect_wp; then
        wp_error "WP is already installed here!"
        return 1
    fi

    [ "$WPOWNER" = root ] && return 2 # no WP for root

    # get data from .wplib
    [ -r "$WPLIBCONF" ] || return 3
    wp_log "reading data from wplibrc"

    # ( now - WPLIB_MTIME ) > 1 hour
    local WPLIB_MTIME="$(stat --format "%Y" "$WPLIBCONF")"
    [ "$(echo "`date "+%s"`-${WPLIB_MTIME};" | bc -q)" -gt 3600 ] && wp_error "wplibrc is older than one hour"

    . "$WPLIBCONF"
    [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$LOCALE" ] || [ -z "$URL" ] \
        || [ -z "$TITLE" ] || [ -z "$ADMINUSER" ] || [ -z "$ADMINPASS" ] || [ -z "$ADMINEMAIL" ] && return 4

    # secret subdir install
    if [ "$WPSECRET" = "--secret" ] \
        && ! [ -z "$STATIC_DIR_NAME" ] \
        && ! [ -z "$SECRET_DIR_NAME" ]; then
        WPSECRET="1"
    else
        unset WPSECRET
    fi

    # mysql credentials in .my.cnf
    mysql --execute="EXIT" || return 5 # 'Please add \n[mysql]\nuser = ...\npassword = ...\nto ~/.my.cnf!'

    wp_log "installing WordPress into $(pwd) in 5 seconds..."
    sleep 5

    # generate DB data
    [ -z "$DBPASS" ] && DBPASS="$(pwgen -cnsB 12 1)"
    [ -z "$DBPREFIX" ] && DBPREFIX="$(pwgen -AnB 6 1)_"
    wp_log "DB prefix: ${DBPREFIX}"

    # create database and user
    mysql --default-character-set=utf8 <<MYSQL || return 6 # "Couldn't setup up database (MySQL error: $?)"
CREATE DATABASE IF NOT EXISTS \`${DBNAME}\`
    CHARACTER SET 'utf8'
    COLLATE 'utf8_general_ci';
-- CREATE USER '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* TO '${DBUSER}'@'localhost'
    IDENTIFIED BY '${DBPASS}';
FLUSH PRIVILEGES;
MYSQL

    # generate wp-cli YAML
    wp_log "generating wp-cli.yaml"
    if [ "$(basename "$WPROOT")" = server ]; then
        YAML_PATH="$(dirname "$WPROOT")/wp-cli.yml"
    else
        YAML_PATH="${WPROOT}/wp-cli.yml"
    fi
    sudo -u "$WPOWNER" -- cat <<YAML > "$YAML_PATH" || return 7 # YAML creation failure
url: ${URL}
user: ${ADMINUSER}
debug: true
core download:
  locale: ${LOCALE}
core update:
  locale: ${LOCALE}
core config:
  dbname: ${DBNAME}
  dbuser: ${DBUSER}
  dbpass: ${DBPASS}
  dbprefix: ${DBPREFIX}
core install:
  title: ${TITLE}
  admin_user: ${ADMINUSER}
  admin_password: ${ADMINPASS}
  admin_email: ${ADMINEMAIL}
#  url: ${URL%/}  https://github.com/wp-cli/wp-cli/issues/1286
skip-plugins: better-wp-security
YAML
    sudo -u "$WPOWNER" -- chmod 640 "$YAML_PATH"

    do_wp__ core download || return 10 # "download failure"

    if [ "$WPSECRET" = 1 ]; then
        # secret dir
        sudo -u "$WPOWNER" -- mkdir "${WPROOT}/${SECRET_DIR_NAME}" || return 14 # "secret dir creation failure"
        sudo -u "$WPOWNER" -- find "$WPROOT" -mindepth 1 -maxdepth 1 -not -name "wp-content" -not -name "$SECRET_DIR_NAME" \
            -exec mv \{\} "${WPROOT}/${SECRET_DIR_NAME}" \; || return 15 # "move to secret"

        # static dir
        sudo -u "$WPOWNER" -- mv "${WPROOT}/wp-content" "${WPROOT}/${STATIC_DIR_NAME}" || return 16 # "rename to static"

        # main index.php
        sudo -u "$WPOWNER" -- cp "${WPROOT}/${SECRET_DIR_NAME}/index.php" "$WPROOT" || return 17 # "copying index.php"
        sudo -u "$WPOWNER" -- sed -i "s|'/wp-blog-header.php'|'/${SECRET_DIR_NAME}/wp-blog-header.php'|" index.php || return 18 # modifying index.php

        # /wp-config.php fail2ban trap
        sudo -u "$WPOWNER" -- tee "${WPROOT}/wp-config.php" > /dev/null <<< '<?php for ( $i = 1; $i <= 6; $i++ ) { error_log( "File does not exist: " . "login_no-wp-here" ); } exit;'

        # do core config, options from YAML
        cat <<WPCFG | do_wp__ core config --extra-php || return 18 # "config failure"
//define( 'WP_DEBUG', false );
define( 'WP_DEBUG', true );

define( 'WP_CONTENT_DIR', '/var/www/subdirwp/server/$STATIC_DIR_NAME' );
define( 'WP_CONTENT_URL', 'http://subdir.wp/$STATIC_DIR_NAME' );

define( 'WP_MAX_MEMORY_LIMIT', '127M' );
define( 'WP_USE_EXT_MYSQL', false );
define( 'WP_POST_REVISIONS', 10 );
define( 'DISALLOW_FILE_EDIT', true );

define( 'DISABLE_WP_CRON', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'ITSEC_FILE_CHECK_CRON', true );
define( 'WP_CACHE', true );
WPCFG
        sudo -u "$WPOWNER" -- chmod 640 "${WPROOT}/${SECRET_DIR_NAME}/wp-config.php" || return 21 # "chown error"

        do_wp__ core install "--url=${URL}/${SECRET_DIR_NAME}" || return 19 # "core install failure"

        # revert home URL
        do_wp__ option set home "$URL" || return 20 # "install failure"
    else
        cat <<WPCFG | do_wp__ core config --extra-php || return 11 # "core config failure"
//define( 'WP_DEBUG', false );
define( 'WP_DEBUG', true );

define( 'WP_MAX_MEMORY_LIMIT', '127M' );
define( 'WP_USE_EXT_MYSQL', false );
define( 'WP_POST_REVISIONS', 10 );
define( 'DISALLOW_FILE_EDIT', true );

define( 'DISABLE_WP_CRON', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'ITSEC_FILE_CHECK_CRON', true );
define( 'WP_CACHE', true );
WPCFG
        sudo -u "$WPOWNER" -- chmod 640 "${WPROOT}/wp-config.php" || return 22 # "chown error"

        # move wp-config to a secure place
        if [ "$(basename "$WPROOT")" = server ]; then
            sudo -u "$WPOWNER" -- mv -v "${WPROOT}/wp-config.php" "$(dirname "$WPROOT")"
        fi

        do_wp__ core install "--url=${URL}" || return 12 # "install failure"
    fi

    # webroot files
    sudo -u "$WPOWNER" -- touch "${WPROOT}/browserconfig.xml" "${WPROOT}/crossdomain.xml" \
        "${WPROOT}/apple-touch-icon.png" "${WPROOT}/apple-touch-icon-precomposed.png"

    # favicon
    cat << FAV | base64 -d | sudo -u "$WPOWNER" -- gzip -d > "${WPROOT}/favicon.ico"
H4sIABpejFMCA6WRXUhTYRjH/3MjP3bRvInuUqnopqC82p2XkZEhYTRzkWdTY1nmLL9wxpyn6aZF
QkROIt0gSwPXpGAq3swgrQgkC5bghcja2i7KMFdbz8t5eYeJVz7nOQfO8/7+z8f7ACp6dDrQdz/q
1MA+AEfopRAKoMR3NM8cTkncB0OY+o5gDMEoXq/i0QyMN1B5HWW17Gg6wd1g5drcXJha8TKMiSU8
ncPIFBz9uFKPE8XsiDCCE2nmvnFkZeHgYVyqRrcLr2YxOsGCnhEMPIShSnWgABoNrO2cJzfX42Qp
upzpbZbt6MkvKVFrtawHwa/9wm0Z/QPovQunWyERDGHwCZ4H1I0trCUyUSL2B4srsDvReAt2mfO+
MSah+OpPSBY+ppBEkwh/g80BWxfnu934uIzIb8RTDBASj4/9UpC6Cs3DdY/zdhkPhhDZyLQtTKkS
3VS9+4Jnfs733YexGjc7MrwooUgo1cJnjAU439OHigvI0265SSHRaFTNNky/wfBoJv/ZcuTkbBlT
kdC+aCnnzkN2Y3yS855hUIY92f/fjLKv02fEpJwf8uLtJ5iuZnoW/I8krG1o76R9PX7/4UV4mfH+
ILvh9b+iZ71FcqcT5L2peOf62qGWpr11lnzJrDPVFLU1N0S+yptRVypOAJGFev1xySBN+oTkTjJ2
0e89WmMsvlZ7zFx1OeBVYMWJxC7tH+5pKEN+AwAA
FAV

    # set ownership to original owner
    chown -R $WPOWNER:$WPGROUP "$WPROOT" || return 13 # "Cannot set ownership"

    check_wpconfig
}

## estimate the size of autoloaded option
autoload_estimate() {
    detect_wp || return 1 # no wp

    do_wp__ eval '$size=0;$opts = wp_load_alloptions();foreach($opts as $name=>$str)$size+=strlen($name.$str)+2;echo $size;'
}

check_root_files() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    local SITEMAP=""

    if do_wp__ plugin list --field=name --name=wordpress-seo --status=active \
        | grep -q "wordpress-seo" \
        && do_wp__ option get wpseo_xml | grep -q "'enablexmlsitemap' => true"; then
        SITEMAP="sitemap_index.xml"
    elif do_wp__ plugin list --field=name --name=google-sitemap-generator --status=active \
        | grep -q "google-sitemap-generator"; then
        SITEMAP="sitemap.xml"
    elif [ -r "${WPROOT}/sitemap.xml.gz" ]; then
        SITEMAP="sitemap.xml.gz"
    elif [ -r "${WPROOT}/sitemap.xml" ]; then
        SITEMAP="sitemap.xml"
    else
        wp_error "sitemap not found"
        return 2 # no sitemap
    fi

    local ROOTFILES=( .htaccess wp-cli.yml favicon.ico \
        apple-touch-icon.png apple-touch-icon-precomposed.png \
        browserconfig.xml crossdomain.xml googlec68b92baad131042.html )
    local VIRTUALFILES=( robots.txt "${SITEMAP}" )
    local SITEURL="$(do_wp__ option get siteurl 2> /dev/null)"

    [ -z "$SITEURL" ] && return 3 # no siteurl

    for FILE in ${ROOTFILES[*]}; do
        [ -r "$FILE" ] || wp_error "root file not found: ${FILE}"
    done
    for FILE in ${VIRTUALFILES[*]}; do
        wget -qO /dev/null -t 3 -T 1 "${SITEURL}/${FILE}" || wp_error "file download failure: ${FILE}"
    done
}


## sample function, don't forget about detect_wp and wp_log and returns
_sample_func() {
    local VAR="$1"
    [ -z "$VAR" ] || die ....


    do_wp core ........ || return 1
}

## initialize terminal colors
term_colors
