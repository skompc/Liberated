<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function TutorialFinish() {
    // Get the 'param' from the query string and decrypt it
    $params = stringToJsonObject(decrypt($_GET['param']));

    // Add the tutorial data to the main JSON file
    $mainFilePath = "../saves/players/0/main.json";
    $mainData = json_decode(file_get_contents($mainFilePath), true);

    // Update the tutorial step and other related data in the main JSON
    $mainData['tutorial_step'] = $params['step'];
    $mainData['tutorial_quest_id'] = 0;
    $mainData['tutorial_quest_name'] = "";
    $mainData['tutorial_prefix'] = "";

    // Save the updated data back to the main JSON file
    file_put_contents($mainFilePath, json_encode($mainData, JSON_PRETTY_PRINT));

    // Send the response as JSON
    
    echo json_encode([
        'res_code' => 0,
        'client_wait' => 0
    ]);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    TutorialFinish();
}
?>
