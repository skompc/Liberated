<?php

require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function TutorialBattleEntry() {
    // Load battle data
    $files = ["../data/battles/tutorial/0.json"];
    $data = combineFiles($files);

    $data['helper'] = new stdClass();

    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode($data);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    TutorialBattleEntry();
}
?>
