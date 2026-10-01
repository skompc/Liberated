<?php

function ArmamentPicture() {
    $filePath = '../../saves/players/0/d2mode/armaments.json';

    // Check if the file exists
    if (file_exists($filePath)) {
        // Read the file content
        $data = file_get_contents($filePath);

    // Create the response array
    $response = [
        "helpers" => [],
        "helper_max" => 1,
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the response as JSON
    
    echo json_encode($response);
    } else {
        // Handle error if file does not exist
        http_response_code(404); // Send a 404 response code
        echo json_encode(["error" => "File not found"]);
    }
}


if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    ArmamentPicture();
}
?>