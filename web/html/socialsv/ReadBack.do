<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function ReadBack() {
    // Get the query parameter
    $params = StringToJsonObject(Decrypt($_GET['param']));

    // Get the igt_id from the parameters
    $id = $params['id'];

    $response = json_decode(file_get_contents("../data/dramas/categories/{$id}.json"), true);

    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    ReadBack();
}
?>
