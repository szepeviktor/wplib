#!/bin/bash

. /usr/local/share/wp/wp-libwp.sh

## wp-lib.sh --root=/var/www/server do-wp   core version


_ROOT="${1#--root=}"
if [ ! "${_ROOT}" = "$1" ]; then
    shift
    wp_log__ "entering: "
    pushd "${_ROOT}"
fi


COMMAND="$1"
shift

case "$COMMAND" in
    get-owner | owner)
        get_owner
        wp_log "owner=${WPOWNER}"
    ;;
    detect-wp | detect)
        detect_wp
        if [ $? = 0 ]; then
            wp_log "wp detected"
        else
            wp_log "NO wp here!"
        fi
    ;;
    do-wp | sudo)
        get_owner
        do_wp $@
        wp_log "exit code: $?"
    ;;
    update-core | update | code-update)
        update_core
        wp_log "exit code: $?"
    ;;
    clear-cache | apc-clear)
        set_root
        wp_log__ "clearing cache reply: '"
        php "$APCDEL" "$WPROOT"
        RET=$?
        echo "'" # missing EOL
        wp_log "exit code: ${RET}"
    ;;
    do-robots | update-robots)
        do_robots
        wp_log "exit code: $?"
    ;;
    itsec-screen | bwps-screen)
        itsec_screen "$1" # <user>
    ;;
    plugin-changelog | changelog)
        plugin_changelog "$1"
    ;;
    plugin-minor-updates | plugin-minor)
        plugin_minor_updates "$1" # --second
    ;;
esac

if [ "$(dirs)" != "$(pwd)" ]; then
    wp_log__ "leaving: "
    popd
fi

