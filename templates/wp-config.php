//define( 'WP_DEBUG', false );
define( 'WP_DEBUG', true );

//define( 'WP_CONTENT_DIR', '/var/www/SITENAME.TLD/server/STATIC_DIR_NAME' );
//define( 'WP_CONTENT_URL', 'http://SITENAME.TLD/STATIC_DIR_NAME' );

define( 'WP_MAX_MEMORY_LIMIT', '127M' );
define( 'WP_USE_EXT_MYSQL', false );
define( 'WP_POST_REVISIONS', 10 );
define( 'DISALLOW_FILE_EDIT', true );
//define( 'WP_CACHE', true );

// # at minute:02 and 32
// 2,32    *   *   *   *   www-data    /usr/local/bin/wp-cron.sh /var/www/SITENAME.TLD/
define( 'DISABLE_WP_CRON', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'ITSEC_FILE_CHECK_CRON', true );

