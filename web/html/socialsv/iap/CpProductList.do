<?php
function CpProcuctList() {
    // Prepare the response
    $response = [
        "product_list" => [],
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the JSON response
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is made
if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    CpProcuctList();
}
?>
