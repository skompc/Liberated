<?php
function ChatStart() {
    // Prepare the response
    $response = [
        "res_code" => 0,
        "client_wait" => 0,
        "room" => [
            [
                "cat" => "s",
                "chan" => 0,
                "name" => "システム",
                "say" => 0
            ],
            [
                "cat" => "w",
                "chan" => 701,
                "name" => "ワールド",
                "say" => 1
            ],
            [
                "cat" => "wgl",
                "chan" => 0,
                "say" => 1
            ]
        ]
    ];

    // Send the JSON response
    
    echo json_encode($response);
}

// Call the function when the request is made
if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    ChatStart();
}
?>
