#!/bin/bash

WPLIB_VERSION="0.1"


. /usr/local/share/wplib/wp-libwp.sh

usage(){
    WPLIB="$(basename $0)"

    cat <<HLP
Usage: ${WPLIB} [--root=<WORDPRESS-ROOT>] <COMMAND> [OPTIONS]
It is a wrapper around wp-cli with sudo.
Turn on profiling by setting WPLIB_PROFILE environment variable.

  --root=<WORDPRESS-ROOT>         set WordPress root directory
  get-owner                       display the owner of the root directory
  chown                           revert the owner of all files recursively
  detect-wp                       detect WordPress installation
  detect-php-errors               detect PHP errors while running wp-cli
  check-yaml                      check wp-cli.yml in the root directory
  do-wp <COMMAND>                 execute any wp-cli command
  full-setup --secret             full setup with DB user creation
                                  setting are read from wplibrc
  update-core                     update WordPress core
  clear-cache                     clear this WordPress installation
                                  from opcode cache
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
  mount-cache <SIZE>              mount WP cache directory to a ramdisk
                                  only root can mount tmpfs, size is in MB
  umount-cache                    un-mount WP cache directory
  autoload-estimate               estimate overall size of autoload options
  check-root-files                check must-have files in WordPress root
  help                            display this help and exit
  version                         display wp-lib version
  help-aliases                    list command aliases

EXAMPLES
    ${WPLIB} --root=/var/www/wp/server detect-wp
    ${WPLIB} --root=/var/www/wp/server do-wp core version --extra
    ${WPLIB} --root=/var/www/wp/server itsec-screen mary
    ${WPLIB} help-aliases
    WPLIB_PROFILE=1 ${WPLIB} --root=/var/www/wp/server sudo plugin list
HLP
}


RET="0"
_ROOT="${1#--root=}"
if [ "${_ROOT}" != "$1" ]; then
    shift
    #wp_log__ "entering: "
# FIXME this won't work if ROOT has perms like 750
    pushd "${_ROOT}" > /dev/null
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
        grep "^[ a-z|-]*)#\$" "$0" | cut -d')' -f1
    ;;
    get-owner | owner)#
        get_owner
        wp_log "owner=${WPOWNER}"
    ;;
    revert-permissions | permissions | chown)#
        [ -d "${_ROOT}" ] || die 1 "no valid dir"
        revert_permissions
        RET="$?"
    ;;
    detect-wp | detect)#
        detect_wp
        RET="$?"
        if [ "$RET" = 0 ]; then
            wp_log "wp is installed"
        else
            wp_error "NO wp here!"
        fi
    ;;
    detect-php-errors | detect-errors)#
        detect_php_errors
        RET="$?"
        if [ "$RET" = 0 ]; then
            wp_log "no PHP errors"
        elif [ "$RET" = 101 ]; then
            wp_error "wp option get siteurl caused errors: $RET"
        elif [ "$RET" = 102 ]; then
            wp_error "wp eval 'echo 1;' caused errors: $RET"
        fi
    ;;
    do-wp | dowp | sudo)#
        get_owner
        do_wp "$@"
        RET="$?"
    ;;
    update-core | update | core-update)#
        update_core
        RET="$?"
    ;;
    clear-cache | opcache-clear | opcache | apc-clear | apc)#
        set_root
        clear_cache
        RET="$?"
    ;;
    do-robots | update-robots)#
        do_robots
        RET="$?"
    ;;
    itsec-screen | bwps-screen)#
        itsec_screen "$1" # <USER>
        RET="$?"
    ;;
    plugin-changelog | changelog)#
        plugin_changelog "$1" # <PLUGIN>
        RET="$?"
    ;;
    plugin-minor-updates | plugin-minor)#
        plugin_minor_updates "$1" # --second
        RET="$?"
    ;;
    plugin-update-except | plugin-except)#
        plugin_update_except "$@"
        RET="$?"
    ;;
    # like in drush
    plugin-update-backup | plugin-update)#
        plugin_update_backup
        RET="$?"
    ;;
    plugin-backup | backup-plugin)#
        plugin_backup "$1" # <PLUGIN>
        RET="$?"
    ;;
    check-wpconfig | check-config | configtest)#
        check_wpconfig
        RET="$?"
    ;;
    mount-cache | mount)#
        mount_cache "$1" # <SIZE>
        RET="$?"
        if [ "$RET" = 0 ]; then
            wp_log "mount OK"
        fi
    ;;
    umount-cache | umount | unmount)#
        umount_cache
        RET="$?"
        if [ "$RET" = 0 ]; then
            wp_log "umount OK"
        fi
    ;;
    check-yaml | yaml)#
        check_yaml
        RET="$?"
    ;;
    full-setup | setup )#
        full_setup "$1" # --secret
        RET="$?"
        if [ "$RET" = 0 ]; then
            wp_log "setup OK."
        fi
    ;;
    autoload-estimate | autoload)#
        wp_log__ "autoload size="
        autoload_estimate
        RET="$?"
        wp_log___
    ;;
    check-root-files | check-files | check-root)#
        check_root_files
        RET="$?"
    ;;
    *)
        wp_error "'${COMMAND}' is not a registered wp command"
        usage
    ;;
esac

## TODO
## - general sudo__ function for shell commands
## - db for sites ~/wp.sql3 wp-s: wproot, owner, locale, siteurl, user, cache mount path
## - check_root_files() {crossdomain.xml}
## - Glacier backup/delete cron
## - use WP_CLI_CONFIG_PATH for sudo instead cd ??
#
## input: /var/www/*/server/wp-cli.yml /home/*/public*/server/wp-cli.yml -OR- wp-load.php
#
#for future use: local YAML_USER="$(do_wp__ eval "echo WP_CLI::get_config('user');")" #"

if [ "$(eval echo `dirs`)" != "$(pwd)" ]; then
    #wp_log__ "leaving: "
    popd > /dev/null
fi

[ "$RET" = 0 ] || wp_error "error: $RET"
exit "$RET"
