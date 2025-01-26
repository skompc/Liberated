<?php
function DevilWatch() {
    // Create the response array
    $response = [
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is a POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    DevilWatch();
}

?>