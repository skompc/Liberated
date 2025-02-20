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

//echo decrypt("639baa34f60013588325ca2d4876849a28bbab13f2135e37d52ec92d4a7984923fae9a03c4151a77967788265a3dd69239b8c943a34705759c24cd4f0f23ccca78ed9618e33e08628a15d76511738fc66fbf8616eb3e1162803fd564416393d120b8ab03fa0d083ac36ce66411119fc171b31735ea76d2c180c613590688977426");
