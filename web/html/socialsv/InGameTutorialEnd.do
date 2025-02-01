<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";

function IngameTutorialEnd() {
    // Get the query parameter
    $params = StringToJsonObject(Decrypt($_GET['param']));

    // Get the tutorial_id from the parameters
    $igt = $params['tutorial_id'];

    // Files to combine
    $files = ['../saves/players/0/igt_list.json'];
    $data = CombineFiles($files);

    // Get the array of tutorial ids
    $numbersArray = $data['igt_list'];

    // Remove the tutorial id from the list
    $filteredArray = array_filter($numbersArray, function($number) use ($igt) {
        return $number !== $igt;
    });

    // Reset the keys of the filtered array
    $filteredArray = array_values($filteredArray);

    // Update the data
    $data['igt_list'] = $filteredArray;

    // Add the updated data to the file
    AddToJson("../data/players/0/igt_list.json", "igt_list", $data['igt_list']);

    // Send the response as JSON
    $response = [
        "igt_id" => $igt,
        "igt_list" => $data['igt_list'],
        "res_code" => 0,
        "client_wait" => 0
    ];

    
    echo json_encode($response);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    IngameTutorialEnd();
}
?>
