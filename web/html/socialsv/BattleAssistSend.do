<?php
function BattleAssistSend() {
    // Create the response array
    $response = [
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the response as JSON
    
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    BattleAssistSend();
}
?>
