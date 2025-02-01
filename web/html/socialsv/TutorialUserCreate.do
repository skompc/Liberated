<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function TutorialUserCreate() {
    // Get the 'param' from the query string and decrypt it
    $params = stringToJsonObject(decrypt($_GET['param']));

    // Load the necessary files
    $mainFilePath = "../saves/players/0/main.json";
    $partyFilePath = "../saves/players/0/party.json";
    $usrFilePath = "../saves/players/0/usr.json";

    $jsonData = json_decode(file_get_contents($mainFilePath), true);
    $jsonData2 = json_decode(file_get_contents($partyFilePath), true);
    $jsonData3 = json_decode(file_get_contents($usrFilePath), true);

    // Set the gender and user name
    $gender = (int) $params['gender'] + 1;
    $jsonData['user_name'] = $params['name'];
    $jsonData2['summoners'][0]['id'] = $gender;
    $jsonData2['parties'][0]['summoner'] = $gender;
    $jsonData3['name'] = $params['name'];
    $jsonData3['usr']['name'] = $params['name'];
    $jsonData3['usr']['smn_id'] = $gender;

    // Save the updated data back to the files
    file_put_contents($mainFilePath, json_encode($jsonData, JSON_PRETTY_PRINT));
    file_put_contents($partyFilePath, json_encode($jsonData2, JSON_PRETTY_PRINT));
    file_put_contents($usrFilePath, json_encode($jsonData3, JSON_PRETTY_PRINT));

    // Add the tutorial step and quest information
    addToJson($mainFilePath, "tutorial_step", 2);
    addToJson($mainFilePath, "tutorial_quest_id", 1);
    addToJson($mainFilePath, "tutorial_quest_name", "First Battle");
    addToJson($usrFilePath, "name", $params['name']);

    // Define the skills for the devils
    $skills1 = [
        ["lv" => 1, "id" => 1001],
        ["lv" => 1, "id" => 1101],
        ["lv" => 1, "id" => 2018],
        ["lv" => 0, "id" => 0],
        ["lv" => 0, "id" => 0],
        ["lv" => 0, "id" => 0],
        ["lv" => 0, "id" => 0]
    ];

    $skills2 = [
        ["lv" => 1, "id" => 1128],
        ["lv" => 1, "id" => 2001],
        ["lv" => 1, "id" => 102117],
        ["lv" => 0, "id" => 0],
        ["lv" => 0, "id" => 0],
        ["lv" => 0, "id" => 0],
        ["lv" => 0, "id" => 0]
    ];

    // Unique IDs for the devils
    $uniq1 = 33333333333;
    $uniq2 = 22222222222;

    // Create and update the devils
    $updateDevils = [
        makeDevil(11710, 1, 1, 14, 10, 10, 13, 10, 0, $skills1, 2, 0, 0, 32, 0, 0, 0, $uniq1, 0),
        makeDevil(12310, 1, 1, 9, 12, 10, 16, 10, 0, $skills2, 1, 0, 64, 0, 0, 0, 0, $uniq2, 0)
    ];

    updateDevils($updateDevils);

    // Add the devils to the party
    add2Party($gender, 1, 0, (int) $uniq1);
    add2Party($gender, 1, 1, (int) $uniq2);

    // Update the home party for the devils
    updateHomeParty(11710, 0);
    updateHomeParty(12310, 1);

    // Update the tutorial step and quest information
    $jsonData['tutorial_step'] = 2;
    $jsonData['tutorial_quest_id'] = 1;
    $jsonData['tutorial_quest_name'] = "First Battle";
    $jsonData['update_devils'] = $updateDevils;

    // Return the updated data as JSON
    
    echo json_encode($jsonData);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    TutorialUserCreate();
}
?>
