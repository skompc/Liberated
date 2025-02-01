<?php
function SNEntry() {
    // Send the response as JSON
    
    echo json_encode([
        'res_code' => 0,
        'client_wait' => 0,
        "nonce" => "225973463_1737500667399"
    ]);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    SNEntry();
}
?>
