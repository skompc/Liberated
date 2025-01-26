<?php
function Chat() {
    // Prepare the response
    $response = [
        "chat" => [],
        "channel" => 700,
        "interval" => 5,
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the JSON response
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is made
if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    Chat();
}
?>
