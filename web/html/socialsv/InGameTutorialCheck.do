<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function IngameTutorialCheck() {
    // Get the query parameter
    $params = StringToJsonObject(Decrypt($_GET['param']));

    // Get the igt_id from the parameters
    $igt = $params['igt_id'];

    // Files to combine
    $files = ['../saves/players/0/igt_list.json'];
    $data = CombineFiles($files);

    // Create the response array
    $response = [
        "igt_id" => $igt,
        "igt_list" => $data['igt_list'],
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    IngameTutorialCheck();
}
?>
