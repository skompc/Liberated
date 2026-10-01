<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function GetBaseData() {
    // Decrypting parameters from the query string
    $params = StringToJsonObject(decrypt($_GET['param']));
    $data2Get = $params['type'];

    // Define the file path and check if the file exists
    $filePath = "../data/common/basedata/" . $data2Get . ".json";
    
    if (file_exists($filePath)) {
        // Read the file content and decode it as JSON
        $data = json_decode(file_get_contents($filePath), true);
    } else {
        // Handle case when the file doesn't exist (optional)
        $data = [
            "res_code" => 1,
            "error_message" => "File not found"
        ];
    }

    // Send the response as JSON
    
    echo json_encode($data);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    GetBaseData();
}
?>
