<?php
require_once "../../tools/jsonTools.php";
// DevilList function to handle the request and return the content of Title.json
function Home() {
    $files = [
        "../../saves/players/0/usr.json",
        "../../saves/players/0/d2mode/home.json",
    ];
    $data = combineFiles($files);

    echo json_encode($data);
}

// Call the DevilList function when a GET request is received
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    Home();
}
?>