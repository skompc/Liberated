<?php

require_once "../tools/jsonTools.php";

function RegistAccount() {
    $accid = 12345;
    $transid = $accid;
    $fid = $accid;
    $uid = $accid;
    $uuid = 0;

    // Define directories
    $dir = "../saves/players/{$uuid}/";
    $temp_dir = "../saves/players/0/temp/";

    // Ensure the temp directory exists
    if (!is_dir($temp_dir)) {
        mkdir($temp_dir, 0777, true);
    }

    // Define the base paths
    $base_path = "../data/base/";

    // Define files to copy
    $files_to_copy = [
        "igt_list.json",
        "setting_data.json",
        "main.json",
        "devils.json",
        "facility.json",
        "map.json",
        "missions.json",
        "society.json",
        "party.json",
        "usr.json",
        "home.json"
    ];

    // Copy the files
    foreach ($files_to_copy as $file) {
        copy($base_path . $file, $dir . $file);
    }

    // Add necessary data to JSON files
    addToJson($dir . "main.json", "friend_id", $fid);
    addToJson($dir . "main.json", "ek", $accid);
    addToJson($dir . "main.json", "usr_id", $uid);

    addToJson($dir . "usr.json", "usr_id", $uid);

    // Return JSON response
    $response = [
        "account_id" => $accid,
        "transfer_id" => $transid,
        "uuid" => $uuid,
        "res_code" => 0,
        "client_wait" => 0
    ];

    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    RegistAccount();
}
?>
