<?php
require_once "../../tools/jsonTools.php";
require_once "../../tools/d2mode/devilTools.php";
require_once "../../tools/dec_enc.php";

// Listen for the GET request and handle it
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['param'])) {
    PartySetEquipConfirmation($_GET['param']);
}

function PartySetEquipConfirmation($param) {
    // Decrypt the input parameter (assumed to be a query string)
    $decrypted = Decrypt($param);
    
    // Use a regular expression to capture all occurrences of 'armament_uniqs'
    $pattern = '/(?:^|&)armament_uniqs=([^&]*)/';
    preg_match_all($pattern, $decrypted, $matches);
    
    // Store the first two armament_uniqs values in variables (if available)
    $uniq1 = isset($matches[1][0]) ? $matches[1][0] : null;
    $uniq2 = isset($matches[1][1]) ? $matches[1][1] : null;

    $arms_array = [
        $uniq1,
        $uniq2
    ];

    $filename = "../../saves/players/0/d2mode/party.json";
    $file = json_decode(file_get_contents($filename),true);

    $file['party']['avatar']['armament_uniqs'] = $arms_array;

        // Create the response array
        $response = [
            "after_avatar" => [
                "accessories_uniqs"=> [
                    0,
                    0,
                    0
                ],
                "armament_uniqs"=> $arms_array,
                "avatar_id"=> 1,
                "base_parameter"=> [
                    "hp"=> 1234,
                    "matk"=> 603,
                    "mdef"=> 571,
                    "patk"=> 750,
                    "pdef"=> 606
                ],
                "dungeon_id"=> 2002,
                "last_parameter"=> [
                    "hp"=> 1335,
                    "matk"=> 603,
                    "mdef"=> 616,
                    "patk"=> 817,
                    "pdef"=> 630
                ],
                "pure_parameter"=> [
                    "agi"=> 150,
                    "luk"=> 150,
                    "mag"=> 130,
                    "str"=> 200,
                    "vit"=> 160
                ],
                "style"=> 10010,
                "uniq"=> 130000040481
            ],
            "res_code" => 0,
            "client_wait" => 0
        ];
    
        // Send the response as JSON
        
        echo json_encode($response);
}
?>
