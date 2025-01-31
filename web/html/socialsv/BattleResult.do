<?php

require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";
require_once "../tools/questTools.php";

function BattleResult() {
    // Get the 'param' from the request body and decrypt it
    $params = stringToJsonObject(decrypt($_POST['param']));

    //$stage = $_GET['stage'];

    // Load the result file based on the stage
    $resultFilePath = "../data/battles/" . $params['stage'] . "/result.json";
    $resultFile = json_decode(file_get_contents($resultFilePath), true);
    $expGained = 100;

    // Load the experience data for the next level
    $expArray = json_decode(file_get_contents("../data/common/exp_next.json"), true)['exp_next'];

    // Get the result of the battle
    $result = $params['result'];

    // Load previous data for devils, summoners, and items
    $dvlBefore = json_decode(file_get_contents("../saves/players/0/temp/dvl_before.json"), true)['dvl_before'];
    $smnBefore = json_decode(file_get_contents("../saves/players/0/temp/smn_before.json"), true)['smn_before'];
    $item = json_decode(file_get_contents("../saves/players/0/temp/item.json"), true)['item'];
    $usr = json_decode(file_get_contents("../saves/players/0/usr.json"), true)['usr'];

    $partyData = json_decode(file_get_contents("../saves/players/0/party.json"), true);
    $smn = $partyData['summoners'];
    $smnSkillIds = $smn[0]['skl'];
    
    $dvl = [];
    $dvlLv = [];

    // Loop through the devils to update their levels and experience
    foreach ($dvlBefore as $i => $obj) {
        $level = $obj['lv'];
        $expPre = $obj['exp'];
        $id = $obj['uniq'];
        $expNext = [$expArray[$level - 1]];

        $dvl2Level = devilLevel($obj['uniq'], $expGained);
        $dvl2Add = devilSearch($obj['uniq']);
        $dvl[] = $dvl2Add;

        $expNew = $dvl2Add['exp'];
        $lvNew = $dvl2Add['lv'];

        for ($j = $level; $j < $lvNew; $j++) {
            $expNext[] = $expArray[$level];
        }

        $dvlLv2Add = [
            "exp_pre" => $expPre,
            "level" => $level,
            "exp_next" => $expNext,
            "id" => $id,
            "exp_new" => $expNew
        ];

        $dvlLv[] = $dvlLv2Add;
    }

    $resultFile['transaction_id'] = "AB-CDE-123456";
    $resultFile['usr'] = $usr;
    $resultFile['reward']['dvl_before'] = $dvlBefore;
    $resultFile['reward']['smn'] = $smnBefore;
    $resultFile['reward']['smn_skill_ids'] = $smnSkillIds;
    $resultFile['reward']['item'] = $item;
    $resultFile['reward']['dvl'] = $dvl;
    $resultFile['reward']['dvl_lv'] = $dvlLv;

    // Update quest based on the battle result
    if ($result == 1) {
        updateQuests((int) $params['stage']);
        mergeDevils();
    } elseif ($result == 0) {
        // Handle failure case (if needed)
    } elseif ($result == 2) {
        // Handle escape case (if needed)
    }

    // Return the result file as a response
    echo json_encode($resultFile);
}

// Call the function when the request is a POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    BattleResult();
}
?>
