<?php

require_once "../tools/dec_enc.php";
require_once "../tools/devilTools.php";

function SummonerSkillLearn() {
    $params = json_decode(stringToJsonObject(decrypt($_GET['param'])), true);
    
    $uniq = $params['uniq'];
    $skill_id = $params['skill_id'];
    
    // Assuming learnSkill function is defined in devilTools class
    $result = learnSkill($uniq, $skill_id);
    
    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode([
        'summoner' => $result,
        'res_code' => 0,
        'client_wait' => 0
    ]);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    SummonerSkillLearn();
}
?>
