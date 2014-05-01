#!/usr/bin/env php
<?php

// query GitHub API
$wpcli_releases = 'https://api.github.com/repos/wp-cli/wp-cli/releases';

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $wpcli_releases);
curl_setopt($ch, CURLOPT_USERAGENT, 'wp-cli updater/1.0');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$wpcli_data = json_decode(curl_exec($ch));
curl_close($ch);

// strip first 'v'
$wpcli_version = preg_replace('/^[^0-9]*(.*)$/', '$1', $wpcli_data[0]->tag_name);

printf($wpcli_version);
