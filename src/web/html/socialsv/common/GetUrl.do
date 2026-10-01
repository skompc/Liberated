<?php
// Define the asset bundle version
$bundle = "custom";

// Listen for the GET request and handle it
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['check_code'])) {
    GetUrl($_GET['check_code']);
}

function GetUrl($check_code) {
    // Define the file paths
    $files = ['../../data/common/GetUrl.json'];
    $jsonData = [];

    // Read and parse the JSON files
    foreach ($files as $file) {
        if (file_exists($file)) {
            $data = file_get_contents($file);
            $jsonData[] = json_decode($data, true);
        }
    }

    // Add asset_bundle_version to the jsonData
    $jsonData[] = ['asset_bundle_version' => "custom"];

    // Merge all arrays from jsonData
    $transformedData = [];
    foreach ($jsonData as $data) {
        $transformedData = array_merge($transformedData, $data);
    }

    // Send the response as JSON
    
    echo json_encode($transformedData);
}
?>
