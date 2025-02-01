<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function TutorialBattleNext() {
    // Get the 'param' from the query string and decrypt it
    $params = stringToJsonObject(decrypt($_GET['param']));

    // Extract the wave value from the params
    $wave = $params['wave'];

    // Read the battle data for the given wave
    $file = "../data/battles/tutorial/" . $wave . ".json";
    if (file_exists($file)) {
        $data = json_decode(file_get_contents($file), true);
    } else {
        // Handle the case where the file doesn't exist (optional)
        $data = ['error' => 'File not found'];
    }

    // Send the response as JSON
    
    echo json_encode($data);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    TutorialBattleNext();
}
?>
