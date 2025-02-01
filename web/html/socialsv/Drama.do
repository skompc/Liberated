<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function Drama() {
    // Decrypting parameters from the query string
    $params = StringToJsonObject(decrypt($_GET['param']));
    $path = urldecode($params['path']);

    // Initialize data
    $data = [];

    // Check if the drama file exists
    $filePath = "../data/dramas/{$path}.json";
    if (file_exists($filePath)) {
        // Read and parse the JSON file if it exists
        $fileContent = file_get_contents($filePath);
        $data = json_decode($fileContent, true);
    } else {
        // If the file doesn't exist, return default error response
        $data = [
            'select_history' => [],
            'res_code' => 0,
            'client_wait' => 0,
            'selects' => [],
            'names' => [],
            'texts' => [
                [
                    'id' => 0,
                    'text' => '[cus color=emphasis]Error:[cus color=end] Drama Not Found.'
                ]
            ],
            'commands' => [],
            'charas' => []
        ];
    }

    // Send the response as JSON
    
    echo json_encode($data);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    Drama();
}
?>
