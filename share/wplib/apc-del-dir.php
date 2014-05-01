<?php

/**
 * When apc.stat is disabled
 * files don't get read from disk
 * thus updating files has no effect
 */


// INSTALL
// download from here
// chown www-data:www-data apc-delete-dir.php
// chmod 640 apc-delete-dir.php


class AESpipe
{
    private $url = '-URL-/apc-del-dir.php';
    private $ua = 'apc cleaner/1.0';
    private $key = '-to-be-filled-in-`pwgen 30 1`';
    private $keyhash = '';
    private $ivsize = 0;


    function __construct() {
        $this->keyhash = mhash(MHASH_SHA256, $this->key);
        $this->ivsize = mcrypt_get_iv_size(MCRYPT_RIJNDAEL_256, MCRYPT_MODE_CBC);
    }

    public function post($data) {
        $iv = mcrypt_create_iv($this->ivsize, MCRYPT_DEV_URANDOM);
        $cipherdata = mcrypt_encrypt(MCRYPT_RIJNDAEL_256, $this->keyhash, md5($data) . $data, MCRYPT_MODE_CBC, $iv);
        $cipherpost = array(
            'c' => base64_encode($iv . $cipherdata)
        );

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $this->url);
        curl_setopt($ch, CURLOPT_USERAGENT, 'apc cleaner/1.0');
        curl_setopt($ch, CURLOPT_POST, count($cipherpost));
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($cipherpost));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $apcok = curl_exec($ch);
        curl_close($ch);

        return $apcok;
    }

    public function decrypt($encrypted) {
        $ciphercomb = base64_decode($encrypted);
        $iv = substr($ciphercomb, 0, $this->ivsize);
        $cipherdata = substr($ciphercomb, $this->ivsize);

        $md5path = mcrypt_decrypt(MCRYPT_RIJNDAEL_256, $this->keyhash, $cipherdata, MCRYPT_MODE_CBC, $iv);
        $md5 = substr($md5path, 0, 32);
        $path = substr(rtrim($md5path, "\0"), 32);

        return (md5($path) === $md5) ? $path : false;
    }
}

function apc_delete_dir($dir) {
    if (! isset($dir)) return 1;
    if (substr($dir, -1) !== '/') {
        $dir .= '/';
    }

    // no APC
    if (! function_exists('apc_cache_info')) return 1;
    $apci = apc_cache_info();

    // no APC opcode cache
    if (! isset($apci['cache_list'])) return 2;

    $apc_del = array();
    foreach ($apci['cache_list'] as $file) {
        // no name of the file ???
        if (! isset($file['filename'])) return 3;

        // to be deleted
        if (strpos($file['filename'], $dir) === 0) {
            $apc_del[] = $file['filename'];
        }
    }

    $not_del = apc_delete_file($apc_del);
    if (empty($not_del)) {
        return 0;
    } else {
        // failed to delete these
        return 10;
    }
}

function notok() {
    // for fail2ban
    error_log('File does not exist: ' . $_SERVER['REQUEST_URI']);
    die;
}



/* ########################################### */

// no php-mcrypt
if (! extension_loaded('mcrypt')) die;

if (php_sapi_name() === 'cli') {

    // send path

    // one argument given
    if (count($argv) === 2) {
        $aes = new AESpipe();
        echo $aes->post($argv[1]);
    }
} else {

    // receive path + clear

    // no POST
    if (empty($_POST['c'])) notok();

    $aes = new AESpipe();
    $path = $aes->decrypt($_POST['c']);
    // decrypt failure
    if ($path === false) notok();

    echo apc_delete_dir($path);
}
