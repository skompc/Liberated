<?php
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";
require_once "../tools/dec_enc.php";

// Listen for the GET request and handle it
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['param'])) {
    BattleEntry($_GET['param']);
}

function BattleEntry($param) {
    // Decrypt the input parameters
    $params = StringToJsonObject(Decrypt($param));

    $type = $params['battle_type'];
    $main_smn = $params['main_smn'];
    $sub_smn = $params['sub_smn'];
    $floor = file_get_contents("../saves/players/0/temp/aura/floor.txt");

    // Define files and read data
    $files = [
        "../data/aura/$floor/battles/0/entry.json"
    ];
    $data = combineFiles($files);

    // Find summoners
    $summoner = findSummoner($main_smn);
    $sub_summoner = findSummoner($sub_smn);

    // Prepare parties
    $parties = json_decode(file_get_contents("../saves/players/0/temp/aura/parties.json"), true);

    // Update quest data
    $data['parties'] = $parties;

    $data['helper'] = new stdClass();

    // Respond with updated data
    
    echo json_encode($data);
}
?>
