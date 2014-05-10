wplib
=====

[wp-cli](https://github.com/wp-cli/wp-cli) shell scripts to manage several websites

#### Install wp-cli

```bash
wget -O/usr/local/bin/wp https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x /usr/local/bin/wp
```


### COMMAND SUMMARY

```
Usage: wp-lib.sh [--root=<WORDPRESS-ROOT>] <COMMAND> [OPTIONS]
It is a wrapper around wp-cli with sudo.
Turn on profiling by setting WPLIB_PROFILE environment variable.

  --root=<WORDPRESS-ROOT>         set WordPress root directory
  get-owner                       display the owner of the root directory
  chown                           revert the owner of all files recursively
  detect-wp                       detect WordPress installation
  detect-php-errors               detect PHP errors while running wp-cli
  do-wp <COMMAND>                 execute any wp-cli command
  full-setup                      full setup with DB user creation
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
  mount-cache <SIZE>              mount WP cache directory to a ramdisk
                                  only root can mount tmpfs, size is in MB
  umount-cache                    un-mount WP cache directory
  help                            display this help and exit
  version                         display wp-lib version
  help-aliases                    list command aliases

EXAMPLES
    wp-lib.sh --root=/var/www/wp/server detect-wp
    wp-lib.sh --root=/var/www/wp/server do-wp core version --extra
    wp-lib.sh --root=/var/www/wp/server itsec-screen mary
    wp-lib.sh help-aliases
    WPLIB_PROFILE=1 wp-lib.sh --root=/var/www/wp/server sudo plugin list
```
