<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function FusionExec() {
    // Get the query parameter
    $params = StringToJsonObject(Decrypt($_GET['param']));

    // Extract the parameters
    $uniq_a = $params['uniq_a'];
    $uniq_b = $params['uniq_b'];
    $id = $params['id'];

        $filePath = '../saves/players/0/devils.json';

    if (!file_exists($filePath)) {
        return false; // File doesn't exist
    }

    $jsonData = file_get_contents($filePath);
    $devils = json_decode($jsonData, true);

    if (!is_array($devils)) {
        return false; // Invalid JSON
    }

    $filteredDevils = array_filter($devils, function ($devil) use ($uniq_a, $uniq_b) {
        // Ensure $devil is an array and contains 'uniq'
        if (!is_array($devil) || !isset($devil['uniq'])) {
            return true; // Keep this object since it doesn't have 'uniq'
        }

        // Convert everything to string for a strict comparison
        $devilUniq = (string) $devil['uniq'];
        return $devilUniq !== (string) $uniq_a && $devilUniq !== (string) $uniq_b;
    });

    $dvl2add = makeDevilAccurate($id, makeUniq(11));

    // Save the updated JSON back to file
    file_put_contents($filePath, json_encode($filteredDevils, JSON_PRETTY_PRINT));

    addToJson("../saves/players/0/devils.json", "devils", [$dvl2add]);

    $data2Ret = [
        "greeting" => "hello there",
        "result" => $dvl2add,
        "res_code" => 0,
        "client_wait" => 0,
        "update_devils" => $dvl2add,
        "is_review" => false
    ];

    echo json_encode($data2Ret);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    FusionExec();
}
?>
