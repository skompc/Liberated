<?php
require_once "../tools/jsonTools.php";
require_once "../tools/dec_enc.php";

// DevilList function to handle the request and return the content of Title.json
function GateDungeon($param) {
    $filePath = '../data/battles/aura/1/refresh.json';

    $params = StringToJsonObject(Decrypt($param));

    $map_pos = $params['map_pos'];

    // update temp files
    $temp_file_name = "../saves/players/0/temp/aura/pos.txt";
    // Write the floor number into the file
    if (file_put_contents($temp_file_name, $map_pos) !== false) {
        //echo "Successfully wrote 1 to $temp_file_name";
    } else {
        //echo "Failed to write to $temp_file_name";
    }

    // Check if the file exists
    if (file_exists($filePath)) {
        // Read the file content
        $data = file_get_contents($filePath);

        // Send the response with the content of the file
        echo $data;
    } else {
        // Handle error if file does not exist
        http_response_code(404); // Send a 404 response code
        echo json_encode(["error" => "File not found"]);
    }
}

// Call the DevilList function when a GET request is received
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    GateDungeon($_POST['param']);
}
?>
