<?php
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";
require_once "../tools/dec_enc.php";

// Listen for the GET request and handle it
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['param'])) {
    BattleEntry($_POST['param']);
}

function BattleEntry($param) {
    // Decrypt the input parameters
    $params = StringToJsonObject(Decrypt($param));
    $floor = file_get_contents("../saves/players/0/temp/aura/floor.txt");

    // Define files and read data
    $files = [
        "../data/battles/aura/$floor/battles/0/result.json"
    ];
    $data = combineFiles($files);

    // Prepare parties
    $parties = json_decode(file_get_contents("../saves/players/0/temp/aura/parties.json"), true);
    $party = json_decode(file_get_contents("../saves/players/0/temp/aura/party.json"), true);
    $devils = json_decode(file_get_contents("../saves/players/0/temp/aura/devils.json"), true);
    $pos = json_decode(file_get_contents("../saves/players/0/temp/aura/pos.txt"), true);

    // Update quest data
    $data['parties'] = $parties;
    $data['ctx']['party'] = $party;
    $data['ctx']['devils'] = $devils;
    $data['ctx']['map_pos'] = $pos;

    // Respond with updated data
    
    echo json_encode($data);
}
?>
