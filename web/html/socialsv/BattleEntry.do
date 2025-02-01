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

    $stage = $params['stage'];
    $main_smn = $params['main_smn'];
    $sub_smn = $params['sub_smn'];
    $main_idx = $params['main_idx'];
    $sub_idx = $params['sub_idx'];
    $smn_id = $params['smn_id'];
    $helper = $params['helper'];
    $is_auto = $params['is_auto'];

    // Define files and read data
    $files = [
        "../data/battles/$stage/0.json"
    ];
    $data = combineFiles($files);

    // Initialize variables for the devils
    $devil0 = [];
    $devil1 = [];
    $devil2 = [];
    $devil3 = [];

    $sub_devil0 = [];
    $sub_devil1 = [];
    $sub_devil2 = [];
    $sub_devil3 = [];

    // Get the uniq values for main and sub summoners
    $uniq0 = (int) partySearch($main_smn, $main_idx, 0);
    $uniq1 = (int) partySearch($main_smn, $main_idx, 1);
    $uniq2 = (int) partySearch($main_smn, $main_idx, 2);
    $uniq3 = (int) partySearch($main_smn, $main_idx, 3);

    if ($sub_smn != 0) {
        $sub_uniq0 = (int) partySearch($sub_smn, $sub_idx, 0);
        $sub_uniq1 = (int) partySearch($sub_smn, $sub_idx, 1);
        $sub_uniq2 = (int) partySearch($sub_smn, $sub_idx, 2);
        $sub_uniq3 = (int) partySearch($sub_smn, $sub_idx, 3);
    } else {
        $sub_uniq0 = 0;
        $sub_uniq1 = 0;
        $sub_uniq2 = 0;
        $sub_uniq3 = 0;
    }

    // Fetch the devil data for main and sub summoners
    $devil0 = ($uniq0 != 0) ? devilSearch($uniq0) : ["remove_me" => true];
    $devil1 = ($uniq1 != 0) ? devilSearch($uniq1) : ["remove_me" => true];
    $devil2 = ($uniq2 != 0) ? devilSearch($uniq2) : ["remove_me" => true];
    $devil3 = ($uniq3 != 0) ? devilSearch($uniq3) : ["remove_me" => true];

    $sub_devil0 = ($sub_uniq0 != 0) ? devilSearch($sub_uniq0) : ["remove_me" => true];
    $sub_devil1 = ($sub_uniq1 != 0) ? devilSearch($sub_uniq1) : ["remove_me" => true];
    $sub_devil2 = ($sub_uniq2 != 0) ? devilSearch($sub_uniq2) : ["remove_me" => true];
    $sub_devil3 = ($sub_uniq3 != 0) ? devilSearch($sub_uniq3) : ["remove_me" => true];

    // Filter out devils that are marked for removal
    $array2filter = [$devil0, $devil1, $devil2, $devil3];
    $array2filter2 = [$sub_devil0, $sub_devil1, $sub_devil2, $sub_devil3];

    $devils = array_values(array_filter($array2filter, fn($element) => !isset($element['remove_me'])));
    $sub_devils = array_values(array_filter($array2filter2, fn($element) => !isset($element['remove_me'])));


    // Find summoners
    $summoner = findSummoner($main_smn);
    $sub_summoner = findSummoner($sub_smn);

    // Prepare parties
    $parties = [
        [
            "devils" => $devils,
            "summoner" => $summoner
        ]
    ];

    // Save battle data
    file_put_contents("../saves/players/0/temp/battle.json", "{}");
    addToJson("../saves/players/0/temp/battle.json", "enemies", $data['enemies']);

    // Save devil data
    $allDevils = array_merge($devils, $sub_devils);
    file_put_contents("../saves/players/0/temp/dvl_before.json", "{}");
    addToJson("../saves/players/0/temp/dvl_before.json", "dvl_before", $allDevils);

    // Save summoner data
    $allSmn = [$summoner, $sub_summoner];
    $allSmn = array_filter($allSmn);
    file_put_contents("../saves/players/0/temp/smn_before.json", "{}");
    addToJson("../saves/players/0/temp/smn_before.json", "smn_before", $allSmn);

    // Save additional data
    file_put_contents("../saves/players/0/temp/devil_add.json", '{"devils": []}');
    file_put_contents("../saves/players/0/temp/item.json", '{"item": {}}');

    // Update quest data
    $data['parties'] = $parties;

    $data['helper'] = new stdClass();

    // Respond with updated data
    
    echo json_encode($data);
}
?>
