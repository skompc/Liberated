<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function PartySet() {
    // Get the query parameter
    $params = StringToJsonObject(Decrypt($_GET['param']));

    // Extract the parameters
    $summoner = $params['summoner'];
    $party = $params['party'];
    $pos = $params['pos'];
    $devil = $params['devil'];
    $is_set = $params['is_set'];

    // Perform the action based on whether is_set is 0 or 1
    if ($is_set == 0) {
        Add2Party($summoner, $party, $pos, 0);
    } else {
        Add2Party($summoner, $party, $pos, $devil);
    }

    // Read the party file
    $file = '../saves/players/0/party.json';
    if (file_exists($file)) {
        $data = json_decode(file_get_contents($file), true);
    } else {
        $data = [];
    }

    // Send the response as JSON
    
    echo json_encode($data);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    PartySet();
}
?>
