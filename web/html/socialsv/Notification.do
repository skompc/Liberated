<?php
function blank() {
    // Prepare the response
    $response = [
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the JSON response
    
    echo json_encode($response);
}

// Call the function when the request is made
if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    blank();
}
?>
