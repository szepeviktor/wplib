#!/bin/bash

## set WPLIB_PROFILE to "1" to get execution profiling values


. /usr/local/bin/libbash

WPLIBROOT="/usr/local/share/wplib"
APCDEL="${WPLIBROOT}/apc-del-dir.php"
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
    echo -e "$@"
}

## echo "wp" prepended in blue background without EOL
wp_log__() {
    echo -ne "${reset}${blueBG}${white}[wp]${reset} $@"
}

## echo with "wp" and with EOL
wp_log() {
    wp_log__ "$@"; echo
}

## echo "wp" prepended in red background
wp_error() {
    echo -e "${reset}${bold}${redBG}${white}[wp]${reset} $@"
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
    which wp > /dev/null || die 99 "no wp-cli"
    php -r 'exit((extension_loaded("suhosin") && strpos(ini_get("suhosin.executor.include.whitelist"), "phar") !== false )?0:1);' || die 99 "suhosin whitelist"
    [ -z "$WPLIB_PROFILE" ] || WPLIB_PSTART="$(date "+%s.%N")"
    sudo -u "$WPOWNER" -- /bin/bash -c "cd \"$WPROOT\"; wp \"\$@\"" wp "$@"
    [ -z "$WPLIB_PROFILE" ] || (echo -n "${reset}${greenBG}${black}[wp]${reset} $@ ";
        echo "scale=3; $(date "+%s.%N")-${WPLIB_PSTART};" | bc -q) >&2
}

## check WPOWNER and WPROOT for wp-cli and sudo
do_wp() {
    [ -z "$WPOWNER" ] && die 97 "owner empty"
    [ -z "$WPROOT" ] && die 96 "wp root not set"
    do_wp__ "$@"
}

## is WP installed?
detect_wp() {
    # this set WPROOT also
    get_owner
    grep -q "debug: true" "${WPROOT}/wp-cli.yml" 2> /dev/null || return 3 # no wp-cli FIXME -> check wp-cli troughoutly
    do_wp core is-installed #|| die 4 "no wp"
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

## clear this WPROOT from APC opcode cache
## needs: external php file
clear_cache() {
    wp_log__ "APC clearing reply: '"
    php "$APCDEL" "$WPROOT"
    local RET=$?
    wp_log___ "', exit code: ${RET}" # missing EOL
}

## update WP core, database and clear APC
update_core() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"
    do_wp core update --force --version="$VERSION" || return 4 #"core update error!"
    do_wp core update-db || return 5 #"db update error!"
    clear_cache
}

## update PC-Robots plugin's settings
do_robots() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"
    local ACTIVE="$(do_wp plugin list 2> /dev/null | grep 'pc-robotstxt' | cut -f2)"

    if [ "$ACTIVE" != "active" ]
    then
        wp_log "no PC-Robots plugin"
        return 2
    fi

    do_wp eval-file "$ROBOTSUPDATES"
}

## hide metaboxes from iThemes Security's admin pages
## param: user
itsec_screen() {
    local USER="$1"

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
        '["itsec_get_started","itsec_security_updates","itsec_need_help","itsec_get_backup"]'  --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_settings \
        '["ssl_options","itsec_security_updates","itsec_need_help","itsec_get_backup"]'  --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_advanced \
        '["advanced_intro","itsec_security_updates","itsec_need_help","itsec_get_backup"]'  --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_backups \
        '["backup_description","backupbuddy_info","itsec_security_updates","itsec_need_help","itsec_get_backup"]'  --format=json
    do_wp__ user meta update "$USER" metaboxhidden_security_page_toplevel_page_itsec_logs \
        '["itsec_log_header","itsec_security_updates","itsec_need_help","itsec_get_backup"]'  --format=json
    do_wp__ user meta update "$USER" screen_layout_security_page_toplevel_page_itsec_logs \
        '"1"' --format=json
}

## show plugin changelog in elinks console browser
## param: plugin name
plugin_changelog() {
    which elinks > /dev/null || return 1 # "no elinks"

    local PLUGIN="$1"
    [ -z "$PLUGIN" ] && return 2 # no plugin name

    wget --quiet --output-file=- "http://api.wordpress.org/plugins/info/1.0/${PLUGIN}" \
        | php -r '$seri=unserialize(stream_get_contents(STDIN)); echo "<h1>$seri->name</h1>".$seri->sections["changelog"];' \
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
    ## backup file named "wplib-bck + sitename + today + plugin name_version"
    local BCK="${BCKDIR}/${SITENAME//[^a-z]}-$(LC_ALL=C date "+%Y%m%d")-${PLUGIN}_${CURRENT}.tar.gz"

    wp_log "backing up: ${PLUGIN}"
    if ! mkdir -p "$BCKDIR"; then
        wp_error "cannot create dir: '${BCKDIR}'"
        return 3
    fi
    tar --create --gzip --absolute-names --directory "$(dirname "$PLUGINDIR")" --file "$BCK" "$(basename "$PLUGINDIR")"
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
    [ -f "$(dirname "$WPROOT")/wp-config.php" ] && WPCONFIG="$(dirname "$WPROOT")/wp-config.php"
    [ -f "${WPROOT}/wp-config.php" ] && WPCONFIG="${WPROOT}/wp-config.php"
    [ -z "$WPCONFIG" ] && return 1
}

## checks defines in wp-config.php, displays found and suggested
check_wpconfig(){
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    find_wpconfig || return 2 # no wp-config
    for DEFINE in WPLANG WP_DEBUG WP_MAX_MEMORY_LIMIT WP_POST_REVISIONS WP_CACHE \
        DISABLE_WP_CRON WP_AUTO_UPDATE_CORE DISALLOW_FILE_EDIT; do
        if ! grep --color -Hn "define.*${DEFINE}" "$WPCONFIG"; then
            case "$DEFINE" in
                WPLANG)
                    wp_error "define('WPLANG', 'hu_HU');"
                ;;
                WP_DEBUG)
                    wp_error "define('WP_DEBUG', false);"
                ;;
                WP_MAX_MEMORY_LIMIT)
                    wp_error "define('WP_MAX_MEMORY_LIMIT', '127M');"
                ;;
                WP_POST_REVISIONS)
                    wp_error "define('WP_POST_REVISIONS', 10);"
                ;;
                WP_CACHE)
                    wp_error "define('WP_CACHE', true);"
                ;;
                DISABLE_WP_CRON)
                    wp_error "define('DISABLE_WP_CRON', true);"
                ;;
                WP_AUTO_UPDATE_CORE)
                    wp_error "define('WP_AUTO_UPDATE_CORE', true);"
                ;;
                DISALLOW_FILE_EDIT)
                    wp_error "define('DISALLOW_FILE_EDIT', true);"
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
    mount -t tmpfs -o size=${SIZE}m,uid=${WPOWNER},gid=${WPGROUP},mode=755 tmpfs "$CACHEDIR" || return 8 # "cannot mount ramdisk"

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

    for OPTION in url user debug; do
        if ! grep --color -Hn "^${OPTION}:" "$WPYML"; then
            case "$OPTION" in
                url)
                    wp_error "user: $(do_wp__ option get siteurl 2> /dev/null)"
                ;;
                user)
                    wp_error "user: $(do_wp__ user list --field=user_login 2> /dev/null | head -n 1)"
                ;;
                debug)
                    wp_error "debug: true"
                ;;
                "core update")
                    wp_error "core update:\n    locale: $(do_wp__ eval 'global $locale; echo $locale;' 2> /dev/null)"
                ;;
            esac
        fi
    done
    # two deep options
    for OPTION2 in "core update|locale"; do
        if ! (grep --color -Hn -A1 "^${OPTION2%|*}:" "$WPYML" \
            && grep -A1 "^${OPTION2%|*}:" "$WPYML" | grep -q "\s*${OPTION2#*|}:"); then
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

    local WPLIBCONF=~/.wplib

    # sample .wplib config file
    false && cat > "$WPLIBCONF" << WPLIBRC
DBNAME="wpcdb"
DBUSER="wpcuser"
#DBPASS="<will be filled in with a 12 characters long random password>"
#DBPREFIX="<a secure prefix will be generated>"

LOCALE="hu_HU"

URL="http://wordpress.tk"
TITLE="WordPress website"

ADMINUSER="viktor"
ADMINPASS="secret"
ADMINEMAIL="viktor@szepe.net"
WPLIBRC

    if detect_wp;then
        wp_error "WP is already installed here!"
        return 1
    fi

    [ "$WPOWNER" = root ] && return 2 # no WP for root

    # get data from .wplib
    [ -r "$WPLIBCONF" ] || return 3
    wp_log "reading data from .wplib"
    local WPLIB_MTIME="$(stat --format "%Y" "$WPLIBCONF")"
    # now - WPLIB_MTIME > 1 hour
    [ "$(echo "`date "+%s"`-${WPLIB_MTIME};" | bc -q)" -gt 3600 ] && wp_error ".wplib is older than one hour"

    . "$WPLIBCONF"
    [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$LOCALE" ] || [ -z "$URL" ] \
        || [ -z "$TITLE" ] || [ -z "$ADMINUSER" ] || [ -z "$ADMINPASS" ] || [ -z "$ADMINEMAIL" ] && return 4

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
CREATE USER '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* TO '${DBUSER}'@'localhost'
    IDENTIFIED BY '${DBPASS}';
FLUSH PRIVILEGES;
MYSQL

    # generate wp-cli YAML
    cat <<YAML > "${WPROOT}/wp-cli.yml"
url: ${URL}
#user: ${ADMINUSER}
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
  extra-php
core install:
  url: ${URL%/}
  title: ${TITLE}
  admin_user: ${ADMINUSER}
  admin_password: ${ADMINPASS}
  admin_email: ${ADMINEMAIL}
YAML

    do_wp__ core download || return 10 # "download failure"
    do_wp__ core config || return 11 # "config failure"
    # move wp-config to a secure place
    [ "$(basename "$WPROOT")" = server ] && mv -v "${WPROOT}/wp-config.php" "$(dirname "$WPROOT")"
    do_wp__ core install || return 12 # "Install failure"
    # get around a bug "#user: ..."
    sed -i 's/^#//g' "${WPROOT}/wp-cli.yml"

    # set ownership to original owner
    chown -R $WPOWNER:$WPGROUP "$WPROOT" || return 12 # "Cannot set ownership"

    check_wpconfig
}

## estimate the size of autoloaded option
autoload_estimate() {
    detect_wp || return 1 # no wp

    do_wp__ eval '$size=0;$opts = wp_load_alloptions();foreach($opts as $name=>$str)$size+=strlen($name.$str)+2;echo $size;'
}


## sample function, don't forget about detect_wp and wp_log and returns
_sample_func() {
    local VAR="$1"
    [ -z "$VAR" ] || die ....

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    do_wp core ........ || return 1
}

## initialize terminal colors
term_colors
