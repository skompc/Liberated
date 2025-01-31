<?php
function ReadBackCategory() {
    // Create the response array
    $response = [
        "categories" => [
            ["id" => 1, "priority" => 1],
            ["id" => 2, "priority" => 4],
            ["id" => 3, "priority" => 6],
            ["id" => 4, "priority" => 8],
            ["id" => 5, "priority" => 7],
            ["id" => 6, "priority" => 2],
            ["id" => 7, "priority" => 3],
            ["id" => 8, "priority" => 5]
        ],
        "res_code" => 0,
        "client_wait" => 0
    ];

    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    ReadBackCategory();
}
?>