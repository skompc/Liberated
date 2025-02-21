<?php
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";
require_once "../tools/dec_enc.php";
require_once "../tools/maze.php";

// Listen for the GET request and handle it
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['param'])) {
    GateDungeonBattleEntry($_GET['param']);
}

function GateDungeonBattleEntry($param) {
    // Decrypt the input parameters
    $params = StringToJsonObject(Decrypt($param));

    $floor = $params['floor'];
    $main_smn = $params['main_smn'];
    $sub_smn = $params['sub_smn'];
    $main_idx = $params['main_idx'];
    $sub_idx = $params['sub_idx'];

    $jsonContent = file_get_contents("../data/aura/$floor/floor_entry.json");
    $data = json_decode($jsonContent, true);

    $darkEnable = false;
    $dmgEnable = false;

    if ($floor > 10){
        $darkEnable = true;
    }

    if ($floor > 20){
        $dmgEnable = true
    }

    $maze = makeMaze($data['ctx']['floor']['size_y'] , $data['ctx']['floor']['size_x'], $darkEnable, $dmgEnable);

    $map = json_decode($maze['txt'], true);

    $data['ctx']['floor']['unit'] = $map;
    $data['ctx']['map_pos'] = $maze['start'];

    $file2mod = json_decode(file_get_contents("../data/aura/$floor/refresh.json"), true);
    $file2mod['update'] = $maze['maze']['update'];
    file_put_contents("../data/aura/$floor/refresh.json", json_encode($file2mod));

    $file2make = "../saves/players/0/temp/aura/full.json";
    file_put_contents($file2make, json_encode($maze['full']['update']));


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

    // Filter out devils that are marked for removal
    $array2filter3 = [$devil0, $devil1, $devil2, $devil3, $sub_devil0, $sub_devil1, $sub_devil2, $sub_devil3];

    $devils3 = array_values(array_filter($array2filter, fn($element) => !isset($element['remove_me'])));

    // Find summoners
    $summoner = findSummoner($main_smn);
    $sub_summoner = findSummoner($sub_smn);

    $data['ctx']['devils'] = $devils3;

    $data['ctx']['party'] = [
        [
            "devils" => [
                $uniq0,
                $uniq1,
                $uniq2,
                $uniq3
            ],
            "summoner" => $main_smn
        ],
        [
            "devils" => [
                $sub_uniq0,
                $sub_uniq1,
                $sub_uniq2,
                $sub_uniq3
            ],
            "summoner" => $sub_smn
        ]
    ];

    // Prepare parties
    $parties = [
        [
            "devils" => $devils,
            "summoner" => $summoner
        ],
        [
            "devils" => $sub_devils,
            "summoner" => $sub_summoner
        ]
    ]; 

    $data['helper'] = new stdClass();

    // update temp files
    $temp_file_name = "../saves/players/0/temp/aura/floor.txt";
    // Write the floor number into the file
    if (file_put_contents($temp_file_name, $floor) !== false) {
        //echo "Successfully wrote 1 to $temp_file_name";
    } else {
        //echo "Failed to write to $temp_file_name";
    }

    $temp_file_name = "../saves/players/0/temp/aura/parties.json";
    if (file_put_contents($temp_file_name, json_encode($parties)) !== false) {
        //echo "Successfully wrote 1 to $temp_file_name";
    } else {
        //echo "Failed to write to $temp_file_name";
    }

    $temp_file_name = "../saves/players/0/temp/aura/party.json";
    if (file_put_contents($temp_file_name, json_encode($data['ctx']['party'])) !== false) {
        //echo "Successfully wrote 1 to $temp_file_name";
    } else {
        //echo "Failed to write to $temp_file_name";
    }

    $temp_file_name = "../saves/players/0/temp/aura/devils.json";
    if (file_put_contents($temp_file_name, json_encode($data['ctx']['devils'])) !== false) {
        //echo "Successfully wrote 1 to $temp_file_name";
    } else {
        //echo "Failed to write to $temp_file_name";
    }
    
    $temp_file_name = "../saves/players/0/temp/aura/map.txt";
    // Write the map data into the file
    file_put_contents($temp_file_name, json_encode($map, JSON_PRETTY_PRINT));

    // Respond with updated data
    
    echo json_encode($data);
}
?>
