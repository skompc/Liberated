<?php
function ChatEntry() {
    // Prepare the response
    $response = [
        "res_code" => 0,
        "client_wait" => 0,
        "room_list" => [
            "s",
            "w",
            "wgl"
        ],
        "key" => "c2295f16-1c81-48b6-bd5f-a699ba77ac02"
    ];

    // Send the JSON response
    header('Content-Type: application/json');
    echo json_encode($response);
}

// Call the function when the request is made
if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    ChatEntry();
}
?>
