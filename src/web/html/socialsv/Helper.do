<?php
function Helper() {
    // Create the response array
    $response = [
        "helpers" => [],
        "helper_max" => 1,
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the response as JSON
    
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    Helper();
}
?>
