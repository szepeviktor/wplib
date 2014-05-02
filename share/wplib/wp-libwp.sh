#!/bin/bash

## wp-cli.yml: url, debug, core/locale
## /etc/wp.sql3 wps: wproot, owner, locale, siteurl, ...?
## /var/www/*/server/wp-cli.yml /home/*/public*/server/wp-cli.yml
## do not die!

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
    echo "$@"
}

## echo "wp" prepended in blue background without EOL
wp_log__() {
    echo -n "${reset}${blueBG}${white}[wp]${reset} $@"
}

## echo with "wp" and with EOL
wp_log() {
    wp_log__ "$@"; echo
}

## echo "wp" prepended in red background
wp_error() {
    echo "${reset}${bold}${redBG}${white}[wp]${reset} $@"
}

## set WPROOT global to current dir
## sets: WPROOT
set_root() {
    WPROOT="$(pwd)"
}

## get owner of the WP root directory
## sets: WPOWNER
get_owner() {
    set_root
    WPOWNER="$(stat -c "%U" "$WPROOT")"
    [ -z "$WPOWNER" ] && die 1 "no owner"
    grep -q "^${WPOWNER}:" /etc/passwd || die 2 "owner does not exist"
}

## call wp-cli with sudo
do_wp__() {
    which wp > /dev/null || die 99 "no wp-cli"
    [ -z "$WPLIB_PROFILE" ] || WPLIB_PSTART="$(date "+%s.%N")"
    sudo -u "$WPOWNER" -i -- wp --path="$WPROOT" $@
    [ -z "$WPLIB_PROFILE" ] || (echo -n "${reset}${greenBG}${black}[wp]${reset} $@ ";
        echo "scale=3; $(date "+%s.%N")-${WPLIB_PSTART};" | bc -q) >&2
}

## check WPOWNER and WPROOT for wp-cli and sudo
do_wp() {
    [ -z "$WPOWNER" ] && die 99 "owner empty"
    [ -z "$WPROOT" ] && die 99 "wp root not set"
    do_wp__ "$@"
}

## is WP installed?
detect_wp() {
    get_owner
    grep -q "debug: true" wp-cli.yml || return 3
    do_wp core is-installed #|| die 4 "no wp"
}

## recursive chown to fix file permissions
revert_permissions() {
    detect_wp
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
    local ACTIVE="$(do_wp plugin list | grep 'pc-robotstxt' | cut -f2)"

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
    local PLUGIN="$1"

    [ -z "$PLUGIN" ] && return 1 # no plugin name

    wget -qO- "http://api.wordpress.org/plugins/info/1.0/${PLUGIN}" \
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

    local BCKDIR="$(eval echo ~)/wplib-bck"
    local SITEURL="$(do_wp__ option get siteurl)"
    local SITENAME="${SITEURL#*//}"
    local BCK="${BCKDIR}/${SITENAME//[^a-z]}-$(LC_ALL=C date "+%Y%m%d")-${PLUGIN}_${CURRENT}.tar.gz"

    wp_log "backing up: ${PLUGIN}"
    ## make a dir named "wplib-bck + sitename + today + plugin name_version"
    mkdir -p "$BCKDIR"
    tar --create --gzip --absolute-names --directory "$(dirname "$PLUGINDIR")" --file "$BCK" "$(basename "$PLUGINDIR")"
}

## backup a plugin
## param: plugin name
plugin_backup() {
    local PLUGIN="$1"

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    [ -z "$PLUGIN" ] && return 2 # no name

    local PLUGINDIR="$(do_wp plugin path "$PLUGIN" --dir)"
    if ! [ -d "$PLUGINDIR" ]; then
        wp_error "dir problem: ${PLUGIN}"
        return 2
    fi
    local CURRENT="$(do_wp__ plugin list --name="$PLUGIN" --fields=version | tail -n +2)"

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
            local UPDATE="$(echo "$PLUGINDATA" | cut -f3)"
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
            local PLUGINDIR="$(do_wp__ plugin path "$PLUGIN" --dir)"
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
            local PLUGINDIR="$(do_wp__ plugin path "$PLUGIN" --dir)"
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
            local PLUGINDIR="$(do_wp__ plugin path "$PLUGIN" --dir)"
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
    [ -f "../wp-config.php" ] && WPCONFIG="$(dirname `pwd`)/wp-config.php"
    [ -f "wp-config.php" ] && WPCONFIG="$(pwd)/wp-config.php"
}

## checks defines in wp-config.php, displays found and suggested
check_wpconfig(){
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"
    find_wpconfig
    for DEFINE in WPLANG WP_DEBUG WP_MAX_MEMORY_LIMIT WP_POST_REVISIONS WP_CACHE \
        DISABLE_WP_CRON WP_AUTO_UPDATE_CORE DISALLOW_FILE_EDIT; do
        if ! grep --color -Hn "define.*${DEFINE}" "$WPCONFIG"; then
            case "$DEFINE" in
                WPLANG)
                    wp_error "define('WPLANG', 'hu_HU');";
                ;;
                WP_DEBUG)
                    wp_error "define('WP_DEBUG', false);";
                ;;
                WP_MAX_MEMORY_LIMIT)
                    wp_error "define('WP_MAX_MEMORY_LIMIT', '127M');";
                ;;
                WP_POST_REVISIONS)
                    wp_error "define('WP_POST_REVISIONS', 10);";
                ;;
                WP_CACHE)
                    wp_error "define('WP_CACHE', true);";
                ;;
                DISABLE_WP_CRON)
                    wp_error "define('DISABLE_WP_CRON', true);";
                ;;
                WP_AUTO_UPDATE_CORE)
                    wp_error "define('WP_AUTO_UPDATE_CORE', true);"
                ;;
                DISALLOW_FILE_EDIT)
                    wp_error "define('DISALLOW_FILE_EDIT', true);";
                ;;
            esac
        fi
    done
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
