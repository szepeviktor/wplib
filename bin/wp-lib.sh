#!/bin/bash

. /usr/local/share/wplib/wp-libwp.sh
WPLIB_VERSION="1.0"

usage(){
    WPLIB="$(basename $0)"
    cat <<HLP
Usage: ${WPLIB} [--root=<WORDPRESS-ROOT>] <COMMAND> [OPTIONS]
It is a wrapper around wp-cli with sudo.

  --root=<WORDPRESS-ROOT>         set WordPress root directory
  get-owner                       display the owner of the root directory
  chown                           revert the owner of all files recursively
  detect-wp                       detect WordPress installation
  do-wp <COMMAND>                 execute any wp-cli command
  update-core                     update WordPress core
  clear-cache                     clear this WordPress installation
                                  from APC opcode cache
  do-robots                       update robots.txt
  itsec-screen <USER>             hide certain elements for the given user
                                  from iThemes Security admin pages
  plugin-changelog <PLUGIN>       show plugin changleog in elinks browser
  plugin-minor-updates            update plugins with no change in the
                                  first version number (before the first dot)
  plugin-minor-updates --second   update plugins with no change in the
                                  first and second version number
  plugin-update-except <PLUGINS>  update all plugins except those listed
  plugin-update-backup            update all plugins with backup
  plugin-backup <PLUGIN>          backs up a given plugin
  check-wpconfig                  check all required defines in wp-config.php
  help                            display this help and exit
  version                         display wp-lib version
  help-aliases                    list command aliases

EXAMPLES
    ${WPLIB} --root=/var/www/wp/server detect-wp
    ${WPLIB} --root=/var/www/wp/server do-wp core version --extra
    ${WPLIB} --root=/var/www/wp/server itsec-screen mary
    ${WPLIB} help-aliases
HLP
}


_ROOT="${1#--root=}"
if [ ! "${_ROOT}" = "$1" ]; then
    shift
    wp_log__ "entering: "
    pushd "${_ROOT}"
fi


COMMAND="$1"
shift

case "$COMMAND" in
    --help | help | usage)#
        usage
    ;;
    --version | version)#
        wp_log "wp-lib $WPLIB_VERSION"
    ;;
    help-aliases | aliases)#
        grep "^[ a-z|-]*)#$" "$0" | cut -d')' -f1
    ;;
    get-owner | owner)#
        get_owner
        wp_log "owner=${WPOWNER}"
    ;;
    revert-permissions | permissions | chown)#
        [ -d "${_ROOT}" ] || die 1 "no valid dir"
        revert_permissions
    ;;
    detect-wp | detect)#
        detect_wp
        if [ $? = 0 ]; then
            wp_log "wp is installed"
        else
            wp_log "NO wp here!"
        fi
    ;;
    do-wp | dowp | sudo)#
        get_owner
        do_wp $@
        wp_log "exit code: $?"
    ;;
    update-core | update | core-update)#
        update_core
        wp_log "exit code: $?"
    ;;
    clear-cache | apc-clear | apc)#
        set_root
        clear_cache
    ;;
    do-robots | update-robots)#
        do_robots
        wp_log "exit code: $?"
    ;;
    itsec-screen | bwps-screen)#
        itsec_screen "$1" # <USER>
    ;;
    plugin-changelog | changelog)#
        plugin_changelog "$1" # <PLUGIN>
    ;;
    plugin-minor-updates | plugin-minor)#
        plugin_minor_updates "$1" # --second
    ;;
    plugin-update-except | plugin-except)#
        plugin_update_except $@
    ;;
    # like in drush
    plugin-update-backup | plugin-update)#
        plugin_update_backup
    ;;
    plugin-backup | backup-plugin)#
        plugin_backup "$1" # <PLUGIN>
    ;;
    check-wpconfig | check-config | configtest)#
        check_wpconfig
    ;;
esac

if [ "$(eval echo `dirs`)" != "$(pwd)" ]; then
    wp_log__ "leaving: "
    popd
fi

