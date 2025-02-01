<?php
require_once "../../tools/jsonTools.php";
require_once "../../tools/d2mode/devilTools.php";
require_once "../../tools/dec_enc.php";

// Listen for the GET request and handle it
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['param'])) {
    BattleEntry($_GET['param']);
}

function BattleEntry($param) {
    // Decrypt the input parameters
    $params = StringToJsonObject(Decrypt($param));

    $stage = $params['stage'];
    $is_auto = $params['is_auto'];

    // Define files and read data
    $files = [
        "../../data/battles/$stage/0.json",
        "../../saves/players/0/d2mode/party.json"
    ];

    $data = combineFiles($files);

    $response = [
        "parties" => [
            [
                "devils" => $data["party"]["devils"]
            ]
        ]
    ];

    $combined = array_merge($data, $response);



    // Respond with updated data
    
    echo json_encode($combined);
}
?>
