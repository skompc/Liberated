<?php

ini_set('memory_limit', '1024M');

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

    $pos = $params['pos'];
    $type = $params['battle_type'];
    $main_smn = $params['main_smn'];
    $sub_smn = $params['sub_smn'];
    $floor = file_get_contents("../saves/players/0/temp/aura/floor.txt");

$mapContent = file_get_contents("../saves/players/0/temp/aura/map.txt");

// Decode JSON into an array
$mapLines = json_decode($mapContent, true);

$selectedMapLine = isset($mapLines[$pos]) ? $mapLines[$pos] : null;

    //echo $selectedMapLine;

    if (($selectedMapLine > 68719476736 && $selectedMapLine < 17592186044416) || ($selectedMapLine - 17592186044416 > 68719476736 && $selectedMapLine - 17592186044416 < 17592186044416)) {
        //echo "BOSS";
    $files = [
        "../data/aura/$floor/battles/boss/entry.json"
    ];
    $data = combineFiles($files);

    } else {

    // Define files and read data
    $files = [
        "../data/aura/$floor/battles/0/entry.json"
    ];
    $data = combineFiles($files);
    }

    $filename = "../data/common/skl_data.json";

    $skl_data = json_decode(file_get_contents($filename), true);

    $skills = $skl_data['dvl_skl'];

    $data['btl_bd']['dvl_skl'] = $skills;

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
