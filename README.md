wplib
=====

wp-cli shell scripts to manage several websites

### COMMAND SUMMARY

```
Usage: wp-lib.sh [--root=<WORDPRESS-ROOT>] <COMMAND> [OPTIONS]
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
    wp-lib.sh --root=/var/www/wp/server detect-wp
    wp-lib.sh --root=/var/www/wp/server do-wp core version --extra
    wp-lib.sh --root=/var/www/wp/server itsec-screen mary
    wp-lib.sh help-aliases
```
