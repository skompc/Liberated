<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function DevilStorageSend() {
    // Decrypt the incoming parameters
    $queryString = decrypt($_POST['param']);

    // Manually extract all occurrences of 'devil_ids'
    $devilIds = [];
    $pairs = explode('&', $queryString);

    foreach ($pairs as $pair) {
        list($key, $value) = explode('=', $pair, 2);
        if ($key === 'devil_ids') {
            $devilIds[] = $value;
        }
    }

    // Process each devil_id
    foreach ($devilIds as $uniq) {
        sendToStorage($uniq);
    }

    // Create the response array
    $response = [
        "res_code" => 0,
        "client_wait" => 0,
        "transaction_id" => "AB-CDE-123456"
    ];

    // Send the response as JSON
    echo json_encode($response);
}

// Call the function when the request is a POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    DevilStorageSend();
}

?>
