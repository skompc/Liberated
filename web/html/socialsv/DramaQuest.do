<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/questTools.php";

function DramaQuest() {
    // Send the initial response as JSON before processing
    
    echo json_encode(['res_code' => 0, 'client_wait' => 0]);

    // Decrypting parameters from the query string
    $params = StringToJsonObject(decrypt($_GET['param']));
    $quest = $params['quest_id'];

    // Call the function to update the quest
    updateQuests($quest);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    DramaQuest();
}
?>
