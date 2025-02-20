<?php
require_once "../tools/jsonTools.php";
require_once "../tools/dec_enc.php";

// Function to handle the request and return the updated data
function GateDungeon($param) {
    $filePath = '../data/aura/1/refresh.json';
    $params = StringToJsonObject(Decrypt($param));

    $map_pos = $params['map_pos'];
    $steps = $params['steps'];

    // Save map position to temp file
    $temp_file_name = "../saves/players/0/temp/aura/pos.txt";
    file_put_contents($temp_file_name, $map_pos);

    // Define file paths
    $mapFile = "../saves/players/0/temp/aura/map.txt";
    $jsonFile = "../data/aura/1/full.json";

    // Read map file
    $rawData = trim(file_get_contents($mapFile));

    // Check if it's JSON or plain text
    $inputArray = json_decode($rawData, true);
    if ($inputArray === null) {
        // Assume newline-separated numbers
        $inputArray = explode("\n", $rawData);
        $inputArray = array_map('intval', array_filter($inputArray)); // Convert to integers
    }

    // Read and decode the JSON file
    $jsonData = json_decode(file_get_contents($jsonFile), true);

    // Validate and update unit number based on steps
    if ($steps !== null && isset($jsonData[$steps])) {
        $inputArray[$steps] = $jsonData[$steps]['unit'];
    }

    // Write the updated array back to the file
    file_put_contents($mapFile, json_encode($inputArray));

    // Convert updated array to JSON format with unit and pos
    $jsonOutput = [];
    foreach ($inputArray as $pos => $unit) {
        $jsonOutput[] = ["unit" => $unit, "pos" => $pos];
    }

    // Check if refresh.json exists and update it
    if (file_exists($filePath)) {
        $data = json_decode(file_get_contents($filePath), true);
        $data['update'] = $jsonOutput;
        file_put_contents($filePath, json_encode($data, JSON_PRETTY_PRINT)); // Save the update
        echo json_encode($data);
    } else {
        http_response_code(404);
        echo json_encode(["error" => "File not found"]);
    }
}

// Handle POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    GateDungeon($_POST['param']);
}
?>
