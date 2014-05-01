<?php

function wplib_read_plugin_api($plugin) {

    if (empty($plugin)) return false;

    $url = 'http://api.wordpress.org/plugins/info/1.0/' . $plugin;

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_USERAGENT, 'wp-plugin-changelog/1.0');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $reply = curl_exec($ch);
    curl_close($ch);

    return $reply;
}

if (count($argv) === 2) {
    $seri = wplib_read_plugin_api($argv[1]);
    $plugin = unserialize($seri);
    echo $plugin->sections['changelog'];
}


/*
    PLUGINCHANGELOG="${WPLIBROOT}/wp-plugin-changelog.php"

    local CHNGLOG="$(mktemp).html"
    php "$PLUGINCHANGELOG" "$1" > "$CHNGLOG"
    elinks "$CHNGLOG"
    rm "$CHNGLOG"
*/
