<?php

function updateDevils($input) {
    $data = json_decode(file_get_contents("../../saves/players/0/devils.json"), true);
    $devilsOwned = $data['devils'];
    $devilsToAdd = $input;

    foreach ($devilsToAdd as $object1) {
        $index = array_search($object1['uniq'], array_column($devilsOwned, 'uniq'));
        if ($index !== false) {
            $devilsOwned[$index] = $object1;
        } else {
            $devilsOwned[] = $object1;
        }
    }

    $data['devils'] = $devilsOwned;
    $data['devil_num'] = count($devilsOwned);

    file_put_contents("../../saves/players/0/devils.json", json_encode($data, JSON_PRETTY_PRINT));
}

function makeDevil($id, $rarity, $lvl, $str, $vit, $mag, $agi, $luk, $arc, $skills, $ai_type, $dr, $wk, $av, $spt, $rp, $ct, $uniq, $exp) {
    $devil = [
        "skl" => $skills,
        "id" => $id,
        "lv" => $lvl,
        "str" => $str,
        "vit" => $vit,
        "mag" => $mag,
        "mp" => $mag,
        "mpmx" => $mag,
        "ai_auto_type" => $ai_type,
        "agi" => $agi,
        "luk" => $luk,
        "arc" => $arc,
        "uniq" => intval($uniq),
        "patk" => floor($str * 2.1 + $lvl * 5.6 + 50),
        "pdef" => floor($str * 0.5 + $vit * 1.1 + $lvl * 5.6 + 50),
        "matk" => floor($mag * 2.1 + $lvl * 5.6 + 50),
        "mdef" => floor($mag * 0.5 + $vit * 1.1 + $lvl * 5.6 + 50),
        "hp" => floor($vit * 2.1 + $lvl * 5.6 + 50),
        "hpmx" => floor($vit * 2.1 + $lvl * 5.6 + 50),
        "exceed_info" => ["opened_num" => 0],
        "recommend_type" => 0,
        "additional_skl" => [],
        "limitbreak" => [
            "effect" => [],
            "num" => 60,
            "open" => []
        ],
        "is_awk" => false,
        "dr" => $dr,
        "wk" => $wk,
        "av" => $av,
        "spt" => $spt,
        "rp" => $rp,
        "contents_type" => $ct,
        "rarity" => $rarity,
        "exp" => $exp,
        "is_new" => true,
        "mgtms" => []
    ];

    return $devil;
}

function add2Party($pos, $dvl) {
    $data = json_decode(file_get_contents("../../saves/players/0/d2mode/party.json"), true);

    $data['party']['devils'][$pos + 1] = $dvl;
    file_put_contents("../../saves/players/0/d2mode/party.json", json_encode($data, JSON_PRETTY_PRINT));
}

function partySearch($summoner, $idx, $pos) {
    $data = json_decode(file_get_contents("../saves/players/0/party.json"), true);

    foreach ($data['parties'] as $party) {
        if ($party['summoner'] == $summoner) {
            foreach ($party['data'] as $partyPos) {
                if ($partyPos['idx'] == $idx) {
                    return $partyPos['devils'][$pos];
                }
            }
        }
    }

    return null;
}

function devilSearch($uniq) {
    $data = json_decode(file_get_contents("../../saves/players/0/devils.json"), true);

    foreach ($data['devils'] as $devil) {
        if ($devil['uniq'] == $uniq) {
            $devil['pressturn'] = 1;
            return $devil;
        }
    }

    return null;
}

function devilLevel($uniq, $expGained) {
    $expArray = json_decode(file_get_contents("../../data/common/exp_next.json"), true)['exp_next'];
    $devil = devilSearch($uniq);

    if ($devil === null) {
        return;
    }

    $expNow = $devil['exp'] + $expGained;
    while ($expNow >= $expArray[$devil['lv']]) {
        $expNow -= $expArray[$devil['lv']];
        $devil['lv'] += 1;
        $devil['str'] += 1;
        $devil['vit'] += 1;
        $devil['mag'] += 1;
        $devil['agi'] += 1;
        $devil['mp'] += 1;
        $devil['mpmx'] += 1;
        $devil['luk'] += 1;
        $devil["patk"] = floor($devil['str'] * 2.1 + $devil['lv'] * 5.6 + 50);
        $devil["pdef"] = floor($devil['str'] * 0.5 + $devil['vit'] * 1.1 + $devil['lv'] * 5.6 + 50);
        $devil["matk"] = floor($devil['mag'] * 2.1 + $devil['lv'] * 5.6 + 50);
        $devil["mdef"] = floor($devil['mag'] * 0.5 + $devil['vit'] * 1.1 + $devil['lv'] * 5.6 + 50);
        $devil["hp"] = floor($devil['vit'] * 2.1 + $devil['lv'] * 5.6 + 50);
        $devil["hpmx"] = floor($devil['vit'] * 2.1 + $devil['lv'] * 5.6 + 50);
    }

    $devil['exp'] = $expNow;
    updateDevils([$devil]);
}

function updateHomeParty($id, $slot) {
    $data = json_decode(file_get_contents("../saves/players/0/home.json"), true);
    $data['party'][$slot] = intval($id);
    file_put_contents("../saves/players/0/home.json", json_encode($data, JSON_PRETTY_PRINT));
}

function summonerDevilSearch($id) {
    $searchId = $id;

    // File path
    $file = "../saves/players/0/party.json";

    // Combine and decode JSON data
    $jsonContent = file_get_contents($file);
    $playerData = json_decode($jsonContent, true);

    // Search for the summoner in the parties
    foreach ($playerData['parties'] as $subObj) {
        if ($subObj['summoner'] == $searchId) {
            return $subObj;
        }
    }

    return null; // If not found
}

function learnSkill($uniq, $skillId) {
    $file = "../saves/players/0/party.json";

    // Read JSON data
    $jsonContent = file_get_contents($file);
    $jsonData = json_decode($jsonContent, true);

    // Find the summoner by unique ID
    foreach ($jsonData['summoners'] as &$summoner) {
        if ($summoner['uniq'] == $uniq) {
            // Find the skill in the lineup
            foreach ($summoner['lineup'] as &$skill) {
                if ($skill['id'] == (int)$skillId) {
                    // Update skill and summoner data
                    $skill['is_learned'] = true;
                    $summoner['skl'][] = (int)$skillId;
                    $summoner['skl_p'] -= 1;

                    // Save updated data
                    file_put_contents($file, json_encode($jsonData, JSON_PRETTY_PRINT));
                    return $summoner;
                }
            }
        }
    }

    return false; // If summoner or skill not found
}

function summonerLevel($id, $exp) {
    $searchId = $id;
    $file = "../saves/players/0/party.json";

    // Load player data
    $jsonContent = file_get_contents($file);
    $playerData = json_decode($jsonContent, true);

    // Find the summoner and update their level
    foreach ($playerData['summoners'] as &$subObj) {
        if ($subObj['id'] == $searchId) {
            $exp1 = $subObj['exp'] + $exp;
            $totalExp = $subObj['exp'];
            $expRequirement = 100 * $subObj['lv'];

            // Level up logic
            while ($totalExp >= $expRequirement) {
                $totalExp -= $expRequirement;
                $now_lv_exp = $expRequirement;
                $expRequirement += 100;
                $subObj['lv'] += 1;
                $subObj['skl_p'] += 1;
                $subObj['next_lv_exp'] = $expRequirement;
                $subObj['now_lv_exp'] = $now_lv_exp;
            }

            $subObj['exp'] = $exp1;

            // Save updated data
            file_put_contents($file, json_encode($playerData, JSON_PRETTY_PRINT));
            return $subObj;
        }
    }

    return null; // If summoner not found
}

function findSummoner($summonerId) {
    $file = "../saves/players/0/party.json";

    // Load player data
    $jsonContent = file_get_contents($file);
    $playerData = json_decode($jsonContent, true);

    // Find the summoner by ID
    foreach ($playerData['summoners'] as $subObj) {
        if ($subObj['id'] == $summonerId) {
            return $subObj;
        }
    }

    return null; // If not found
}

function usrLevel($exp) {
    $data = json_decode(file_get_contents("../saves/players/0/usr.json"), true);
    $usr = $data['usr'];

    $usrExp = $usr['exp'] + $exp;
    $expRequirement = 100 * $usr['lv'];
    while ($usrExp >= $expRequirement) {
        $usrExp -= $expRequirement;
        $usr['lv'] += 1;
        $expRequirement += 100;
    }

    $usr['exp'] = $usrExp;
    $data['usr'] = $usr;
    file_put_contents("../saves/players/0/usr.json", json_encode($data, JSON_PRETTY_PRINT));
}

function talkFind($tgt) {
    $searchUniq = $tgt;

    // File path
    $file = "../saves/players/0/temp/battle.json";

    // Load and decode JSON data
    $jsonContent = file_get_contents($file);
    $devilData = json_decode($jsonContent, true);

    // Search for the enemy with the matching 'uniq' value
    foreach ($devilData['enemies'] as $subObj) {
        if ($subObj['uniq'] == $searchUniq) {
            return $subObj; // Return the matched sub-object
        }
    }

    return null; // Return null if no match is found
}

function mergeDevils() {
    // Read the first JSON file
    $file1 = "../../saves/players/0/devils.json";
    $json1 = file_get_contents($file1);
    $data1 = json_decode($json1, true);

    // Read the second JSON file
    $file2 = "../../saves/players/0/temp/devil_add.json";
    $json2 = file_get_contents($file2);
    $data2 = json_decode($json2, true);

    // Check if 'devils' key exists in both JSONs
    if (isset($data1['devils']) && is_array($data1['devils']) && isset($data2['devils']) && is_array($data2['devils'])) {
        // Merge the arrays
        $data1['devils'] = array_merge($data1['devils'], $data2['devils']);
    } else {
        echo "Error: 'devils' key is missing or not an array in one of the files.";
        return;
    }

    // Write the updated JSON back to the output file
    $outputFile = "../../saves/players/0/devils.json";
    $updatedJson = json_encode($data1, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    file_put_contents($outputFile, $updatedJson);
}

?>
