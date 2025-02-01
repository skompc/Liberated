<?php
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function Home() {
    // File paths
    $partyFile = "../saves/players/0/party.json";
    $usrFile = "../saves/players/0/usr.json";

    // Combine JSON data
    $data0 = combineFiles([$partyFile]);
    $data_usr = combineFiles([$usrFile]);

    // Get summoner ID
    $summoner = $data_usr['usr']['smn_id'];

    // Search for devils in the party
    $uniq0 = (int) partySearch($summoner, 1, 0);
    $uniq1 = (int) partySearch($summoner, 1, 1);
    $uniq2 = (int) partySearch($summoner, 1, 2);
    $uniq3 = (int) partySearch($summoner, 1, 3);

    // Initialize devil data
    $devil0 = $uniq0 != 0 ? devilSearch($uniq0) : null;
    $devil1 = $uniq1 != 0 ? devilSearch($uniq1) : null;
    $devil2 = $uniq2 != 0 ? devilSearch($uniq2) : null;
    $devil3 = $uniq3 != 0 ? devilSearch($uniq3) : null;

    // Get devil IDs
    $devil0_id = $devil0 ? $devil0['id'] : 0;
    $devil1_id = $devil1 ? $devil1['id'] : 0;
    $devil2_id = $devil2 ? $devil2['id'] : 0;
    $devil3_id = $devil3 ? $devil3['id'] : 0;

    // Update home party
    updateHomeParty($devil0_id, 0);
    updateHomeParty($devil1_id, 1);
    updateHomeParty($devil2_id, 2);
    updateHomeParty($devil3_id, 3);

    // Combine additional files
    $files = [
        "../saves/players/0/main.json",
        "../saves/players/0/igt_list.json",
        "../saves/players/0/setting_data.json",
        "../saves/players/0/usr.json",
        "../saves/players/0/home.json",
        "../saves/players/0/devils.json"
    ];
    $data = combineFiles($files);

    // Add additional response properties
    $data['client_wait'] = 0;
    $data['res_code'] = 0;

    // Send response
    
    echo json_encode($data);
}

// Call the function when the request is made
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    Home();
}
?>
