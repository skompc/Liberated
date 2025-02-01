<?php
// DevilList function to handle the request and return the content of Title.json
function DevilList() {
    $filePath = '../saves/players/0/devils.json';

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

// Call the DevilList function when a GET request is received
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    DevilList();
}
?>
