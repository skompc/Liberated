<?php

ini_set('memory_limit', '1024M');

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

    $combined['avatar']['armament_uniqs'] = $combined['party']['avatar']['armament_uniqs'];

    $battle_bd_file = "../../data/common/skl_data.json";

    $battle_bd = json_decode(file_get_contents($battle_bd_file), true);

    $combined['btl_bd']['dvl_skl'] = $battle_bd['dvl_skl'];



    // Respond with updated data
    
    echo json_encode($combined);
}
?>
