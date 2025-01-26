<?php

require_once "../tools/jsonTools.php";
require_once "../tools/dec_enc.php";

function Login() {
    // Assuming you have a decrypt function
    $params = StringToJsonObject(decrypt($_GET['param']));

    // Debugging output (you can remove this in production)
    // var_dump($params);

    // Set initial values (in your example, uuid is always 0)
    $uuid = 0;
    $check_code = $params['check_code'];

    // Define file paths to read
    $files = [
        "../saves/players/{$uuid}/main.json",
        "../saves/players/{$uuid}/igt_list.json",
        "../saves/players/{$uuid}/setting_data.json",
        "../saves/players/{$uuid}/usr.json",
        "../data/common/basedata/basedata_version.json",
        "../data/common/rand_names.json",
        "../saves/players/{$uuid}/devils.json"
    ];

    // Combine the files into one data array
    $data = combineFiles($files);

    // Add additional fields to the data
    $data['client_wait'] = 0;
    $data['res_code'] = 0;
    $data['latest_version'] = $check_code;
    $data['ek'] = "12345";
    $sid = "8380D1ABCA94165B85D43B388ABF5257-n2";
    $data['sid'] = $sid;

    // Set a cookie for the session ID
    setcookie('JSESSIONID', $sid, time() + 3600, '/', '', true, true); // Secure and HttpOnly flags

    // Send the response as JSON
    header('Content-Type: application/json');
    echo json_encode($data);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    Login();
}
?>
