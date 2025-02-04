<?php

function DevilStorage() {
    $filePath = '../saves/players/0/storage.json';

    // Check if the file exists
    if (file_exists($filePath)) {
        // Read the file content
        $data = file_get_contents($filePath);

        // Send the response with the content of the file
         // Set the correct content type
        echo $data;
    } else {
        // Handle error if file does not exist
        http_response_code(404); // Send a 404 response code
        echo json_encode(["error" => "File not found"]);
    }
}


if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    DevilStorage();
}
?>