<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');

function updateDevils($input) {
    $filePath = "saves/players/0/devils.json";

    // Load existing data
    $data = json_decode(file_get_contents($filePath), true);
    if (!$data) {
        $data = ["devils" => [], "devil_num" => 0];
    }

    $devilsOwned = $data['devils'];

    // Check if devil already exists
    $index = array_search($input['uniq'], array_column($devilsOwned, 'uniq'));
    if ($index !== false) {
        $devilsOwned[$index] = $input; // Update existing devil
    } else {
        $devilsOwned[] = $input; // Add new devil
    }

    $data['devils'] = $devilsOwned;
    $data['devil_num'] = count($devilsOwned);

    file_put_contents($filePath, json_encode($data, JSON_PRETTY_PRINT));
}

function makeDevil($data) {
    return [
        "skl" => $data['skills'],
        "id" => $data['id'],
        "lv" => $data['lvl'],
        "str" => $data['str'],
        "vit" => $data['vit'],
        "mag" => $data['mag'],
        "mp" => 10,
        "mpmx" => 10,
        "ai_auto_type" => $data['ai_type'],
        "agi" => $data['agi'],
        "luk" => $data['luk'],
        "arc" => $data['arc'],
        "uniq" => intval($data['uniq']),
        "patk" => floor($data['str'] * 2.1 + $data['lvl'] * 5.6 + 50),
        "pdef" => floor($data['str'] * 0.5 + $data['vit'] * 1.1 + $data['lvl'] * 5.6 + 50),
        "matk" => floor($data['mag'] * 2.1 + $data['lvl'] * 5.6 + 50),
        "mdef" => floor($data['mag'] * 0.5 + $data['vit'] * 1.1 + $data['lvl'] * 5.6 + 50),
        "hp" => floor($data['vit'] * 2.1 + $data['lvl'] * 5.6 + 50),
        "hpmx" => floor($data['vit'] * 2.1 + $data['lvl'] * 5.6 + 50),
        "exceed_info" => ["opened_num" => 0],
        "recommend_type" => 0,
        "additional_skl" => [],
        "limitbreak" => [
            "effect" => [],
            "num" => 60,
            "open" => []
        ],
        "is_awk" => true,
        "dr" => $data['dr'],
        "wk" => $data['wk'],
        "av" => $data['av'],
        "spt" => $data['spt'],
        "rp" => $data['rp'],
        "contents_type" => $data['ct'],
        "rarity" => $data['rarity'],
        "exp" => $data['exp'],
        "is_new" => true,
        "mgtms" => []
    ];
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Read JSON input
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (!$data) {
        die(json_encode(["error" => "Invalid JSON input"]));
    }

    // Validate skills array
    if (!isset($data['skills']) || !is_array($data['skills'])) {
        die(json_encode(["error" => "Skills should be an array"]));
    }

    // Create devil
    $devil = makeDevil($data);

    // Save devil
    updateDevils($devil);

    // Respond with new devil data
    echo json_encode($devil);
}
?>
