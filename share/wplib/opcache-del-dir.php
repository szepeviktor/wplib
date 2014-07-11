<?php

/**
 * When opcache.validate_timestamps / apc.stat is disabled
 * files don't get read from disk
 * thus updating files has no effect
 */


// INSTALL
// chown www-data:www-data opcache-delete-dir.php
// chmod 640 opcache-delete-dir.php
// fill in $url and $key


class AESpipe
{
    private $url = '-URL-/opcache-del-dir.php';
    private $key = '-to-be-filled-in-`pwgen 30 1`';
    private $ua = 'opcache cleaner/1.1';
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
        curl_setopt($ch, CURLOPT_USERAGENT, $this->ua);
        curl_setopt($ch, CURLOPT_POST, count($cipherpost));
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($cipherpost));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $del_ok = curl_exec($ch);
        curl_close($ch);

        return $del_ok;
    }

    public function decrypt($encrypted) {
        $ciphercomb = base64_decode($encrypted);
        $iv = substr($ciphercomb, 0, $this->ivsize);
        $cipherdata = substr($ciphercomb, $this->ivsize);

        $md5path = mcrypt_decrypt(MCRYPT_RIJNDAEL_256, $this->keyhash, $cipherdata, MCRYPT_MODE_CBC, $iv);
        $md5 = substr($md5path, 0, 32);
        $path = substr(rtrim($md5path, "\0"), 32);

        $path_ok = (md5($path) === $md5) ? $path : false;
        return $path_ok;
    }
}

function do_opcache_delete($dir) {
    // no status
    if (! function_exists('opcache_get_status')) return 1;
    $opi = opcache_get_status(true);

    // no opcode cache
    if (! isset($opi['scripts'])) return 2;

    foreach ($opi['scripts'] as $file => $status) {
        // to be deleted
        if (strpos($status['full_path'], $dir) === 0) {
            // always OK
            opcache_invalidate($status['full_path']);
        }
    }

    // return empty for success
    return '';
}

function do_apc_delete($dir) {
    // no info
    if (! function_exists('apc_cache_info')) return 1;

    $apci = apc_cache_info();

    // no opcode cache
    if (! isset($apci['cache_list'])) return 2;

    $apc_del = array();
    foreach ($apci['cache_list'] as $file) {
        // no file name
        if (! isset($file['filename'])) return 3;

        // matches dir
        if (strpos($file['filename'], $dir) === 0) {
            $apc_del[] = $file['filename'];
        }
    }

    return apc_delete_file($apc_del);
}

function opcache_delete_dir($dir, $cache_type) {
    if (! isset($dir)) return 1;

    // prepend slash
    if (substr($dir, -1) !== '/') {
        $dir .= '/';
    }

    switch ($cache_type) {
        case 1:
            $not_del = do_opcache_delete($dir);
            break;
        case 2:
            $not_del = do_apc_delete($dir);
            break;
    }

    if (empty($not_del)) {
        // OK
        return 0;
    }

    if (is_int($not_del)) {
        // do_*_delete() error code
        return $not_del;
    } else {
        // failed to delete some
        return 10;
    }
}

function opcache_enabled() {
    return extension_loaded('Zend OPcache') && ('1' == ini_get('opcache.enable'));
}
function apc_enabled() {
    return extension_loaded('apc') && ('1' == ini_get('apc.enabled'));
}

function notok() {
    // log line for fail2ban
    error_log('File does not exist: ' . filter_var($_SERVER['REQUEST_URI'], FILTER_SANITIZE_URL));
    die;
}



/* ########################################### */

// no mcrypt
if (! extension_loaded('mcrypt')) exit(1);

// apc or opcache ?
if (opcache_enabled()) {
    $cache_type = 1;
} elseif (apc_enabled()) {
    $cache_type = 2;
} else {
    notok();
}

if (php_sapi_name() === 'cli') {
    // send on CLI

    // one argument given
    if (2 !== count($argv)) notok();

    $aes = new AESpipe();

    print $aes->post($argv[1]);
} else {
    // receive on the webserver

    // no POST
    if (empty($_POST['c'])) notok();

    $aes = new AESpipe();

    $path = $aes->decrypt($_POST['c']);

    // decrypt failure
    if ($path === false) notok();

    print opcache_delete_dir($path, $cache_type);
}

