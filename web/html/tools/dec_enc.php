<?php

function encrypt($dec, $KEY) {
    $sigFooter = substr($KEY . "ABCDEFGHIJKL", 2, 7) . " ";
    $sigFooterBytes = $sigFooter;
    $decBytes = $dec;

    // Generate signature
    $sig = hash('md5', $decBytes . $sigFooterBytes, true);

    // Generate key material and encryption key
    $keyMaterial = substr(hash('md5', $decBytes, true), 0, 4);
    $key = hash('md5', $keyMaterial, true);

    // XOR encryption
    $enc = '';
    for ($i = 0; $i < strlen($decBytes); $i++) {
        $enc .= chr(ord($decBytes[$i]) ^ ord($key[$i % strlen($key)]));
    }

    return bin2hex($keyMaterial . $enc . $sig);
}

function decrypt($enc) {
    $KEY = "__L_TMS_2D__";

    $sigFooter = substr($KEY . "ABCDEFGHIJKL", 2, 7) . " ";
    $sigFooterBytes = $sigFooter;

    // Decode the input
    $encBytes = hex2bin($enc);
    $keyMaterial = substr($encBytes, 0, 4);
    $encData = substr($encBytes, 4, -16);
    $sig = substr($encBytes, -16);

    // Generate decryption key
    $key = hash('md5', $keyMaterial, true);

    // XOR decryption
    $dec = '';
    for ($i = 0; $i < strlen($encData); $i++) {
        $dec .= chr(ord($encData[$i]) ^ ord($key[$i % strlen($key)]));
    }

    // Verify key material
    $keyCorrect = substr(hash('md5', $dec, true), 0, 4) === $keyMaterial;

    // Verify signature
    $sigCorrect = hash('md5', $dec . $sigFooterBytes, true) === $sig;

    if ($keyCorrect && $sigCorrect) {
        //echo "decrypted: " . $dec . PHP_EOL;
    } elseif ($keyCorrect) {
        //echo "decrypted: " . $dec . PHP_EOL;
        //echo "Signature invalid" . PHP_EOL;
    } else {
        //echo "decrypted: " . $dec . PHP_EOL;
        //echo "Key invalid" . PHP_EOL;
    }

    return $dec;
}

//echo decrypt("4fbf2c225833a3623f10bae4b6d992a91d3f374a5833a3623f10bae4b6d992a91d3c374a5833a3623f10bae4b6d992a91d3d374a5833a3623f10bae4b6d992a91d3a374a5833a3623f10bae4b6d992a91d3b374a5833a3623f10bae4b6d992a91d38374a5833a3623f10bae4b6d992a91c3f374a5833a3623f10bae4b6d992a91c3c374a5833a3623f10bae4b6d992a91c3d374a6322b8546e7de5ebb89131402c8351f1792ea77f96a40f");
