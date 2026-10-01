<?php

require_once "../tools/jsonTools.php";
require_once "../tools/dec_enc.php";

function BattleNext() {
    // Decrypting parameters from the query string
    $params = StringToJsonObject(decrypt($_GET['param']));

    // Extract stage and wave from the parameters
    $stage = $params['stage'];
    $wave = $params['wave'];

    // Define the file path based on the stage and wave
    $filePath = "../data/battles/{$stage}/{$wave}.json";

    // Read the file content
    if (file_exists($filePath)) {
        $fileContent = file_get_contents($filePath);
        $data = json_decode($fileContent, true);

        // Write an empty JSON object to the battle file
        file_put_contents("../saves/players/0/temp/battle.json", "{}");

        // Add enemies to the battle JSON file (using your custom 'addTo' function)
        addToJson("../saves/players/0/temp/battle.json", "enemies", $data["enemies"]);

        // Send the response as JSON
        
        echo json_encode($data);
    } else {
        // Handle error if the file does not exist
        header('HTTP/1.1 404 Not Found');
        echo json_encode(['error' => 'File not found']);
    }
}


// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    BattleNext();
}
?>
