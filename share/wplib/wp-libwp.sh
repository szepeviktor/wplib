#!/bin/bash

## wp-cli.yml: url, debug, core/locale
## wp-config:  define('WP_AUTO_UPDATE_CORE', false);
## /etc/wp.sql3 wps: wproot, owner, locale, siteurl, ...?
## /var/www/*/server/wp-cli.yml /home/*/public*/server/wp-cli.yml
## do not die!

. /usr/local/bin/libbash

WPLIBROOT="/usr/local/share/wplib"
APCDEL="${WPLIBROOT}/apc-del-dir.php"
ROBOTSUPDATES="${WPLIBROOT}/wp-robots-update.php"


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

wp_log__() {
    echo -n "${reset}${blueBG}${white}[wp]${reset} $@"
}

wp_log() {
    wp_log__ "$@"; echo
}

wp_error() {
    echo "${reset}${bold}${redBG}${white}[wp]${reset} $@"
}

set_root() {
    WPROOT="$(pwd)"
}

get_owner() {
    set_root
    WPOWNER="$(stat -c "%U" "$WPROOT")"
    [ -z "$WPOWNER" ] && die 1 "no owner"
    grep -q "^${WPOWNER}:" /etc/passwd # || die 2 "owner does not exist"
}
#revert permissions() {
#    wp_log "reverting permissions"
#    chown -R $OWNER:$OWNER . || die 7 "chown error!"
#}

do_wp__() {
    which wp > /dev/null || die 99 "no wp-cli"
    sudo -u "$WPOWNER" -i -- wp --path="$WPROOT" $@
}

do_wp() {
    [ -z "$WPOWNER" ] && die 99 "owner empty"
    [ -z "$WPROOT" ] && die 99 "wp root not set"
    do_wp__ "$@"
}

detect_wp() {
    get_owner
    grep -q "debug: true" wp-cli.yml || return 3
    do_wp core is-installed #|| die 4 "no wp"
}

update_core() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    do_wp core update --force --version="$VERSION" || return 4 #"core update error!"
    do_wp core update-db || return 5 #"db update error!"

    wp_log__ "clearing APC cache: '"
    php "$APCDEL" "$WPROOT" || return 6 # "couldn't clear APC"
    echo "'"
}

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

plugin_changelog() {
    local PLUGIN="$1"

    [ -z "$PLUGIN" ] && return 1 # no plugin name

    wget -qO- "http://api.wordpress.org/plugins/info/1.0/${PLUGIN}" \
        | php -r '$seri=unserialize(stream_get_contents(STDIN)); echo $seri->sections["changelog"];' \
        | elinks -force-html
}

plugin_minor_updates() {
    local SECOND="$1"

    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    do_wp plugin list --update=available --fields=name | tail -n +2 \
        | while read PLUGIN; do
            local MINOR="$(do_wp__ plugin update "$PLUGIN" --dry-run | tail -n +3)"
            local CURRENT="$(echo "$MINOR" | cut -f3)"
            local UPDATE="$(echo "$MINOR" | cut -f4)"
            local IFS="."
            local CURRENT=($CURRENT)
            local UPDATE=($UPDATE)
            if [ "${UPDATE[0]}" = "${CURRENT[0]}" ] \
                || ([ "$SECOND" = "--second" ] && [ "${UPDATE[1]}" = "${CURRENT[1]}" ]); then
                plugin_changelog "$PLUGIN"
                continue
            fi
            do_wp__ plugin update "$PLUGIN" || wp_error "plugin update failed"
        done
}

_sample_func() {
    detect_wp || return 1 # no wp
    wp_log "owner=${WPOWNER}"

    do_wp core ........ || return 1
}

term_colors
