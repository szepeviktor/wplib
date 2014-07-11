<?php

/**
 * update PC Robots plugin's option from szepe.net
 * Version: 1.1
 */

define('MAIN_ROBOTSTXT', 'http://szepe.net/robots.txt');


// main robots.txt's "Disallow" section ends with a line of hash signs
$find = '/^(.+)###+([^#].+)$/sDU';
$new = '$1';
$rest = '##################################$2';

if (false === is_plugin_active('pc-robotstxt/pc-robotstxt.php')) die(10);

// current
$pc = get_option('pc_robotstxt');
if (false === $pc) die(2);
if (empty($pc['user_agents'])) die(3);

// new
$new_robots = file_get_contents(MAIN_ROBOTSTXT);
if (false === $new_robots) die(4);
$new_user_agents = preg_replace($find, $new, $new_robots);

// do update
$pc['user_agents'] = $new_user_agents . preg_replace($find, $rest, $pc['user_agents']);
$upd = update_option('pc_robotstxt', $pc);
if (false === $upd) die(5);

