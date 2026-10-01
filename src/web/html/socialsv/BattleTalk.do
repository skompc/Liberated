<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function BattleTalk() {
    // Decrypting parameters from the query string
    $params = StringToJsonObject(decrypt($_GET['param']));
    $tgt = $params['tgt'];
    $select = $params['select'];

    // Find the devil to talk to
    $devil2TalkTo = talkFind($tgt);
    $devilId = $devil2TalkTo['id'];

    // Check if select is 1, then add the demon to party
    if ($select == 1) {
        // Add demon to party (using jsonTools.addTo)
        $devil2TalkTo['exp'] = 0;
        $devil2TalkTo['mpmx'] = 10;
        $devil2TalkTo['mp'] = 10;
        $devil2TalkTo['uniq'] = makeUniq(11);
        addToJson("../saves/players/0/temp/devil_add.json", "devils", [$devil2TalkTo]);

        // Prepare devil to add
        $devil2add = [
            'param' => "0",
            'num' => 1,
            'is_bonus' => false,
            'id' => $devilId,
            'type' => 1
        ];

        // Add item to temp item file (using jsonTools.addTo)
        addToArray("../saves/players/0/temp/item.json", "item", $devil2add);
    }

    // Read the talk file based on devilId and select
    $filePath = "../data/talks/10910/{$select}.json";
    if (file_exists($filePath)) {
        $fileContent = file_get_contents($filePath);
        $data = json_decode($fileContent, true);

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
    BattleTalk();
}
?>
