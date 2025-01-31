<?php

function combineFiles($files) {
    $jsonData = [];

    foreach ($files as $file) {
        $data = file_get_contents($file);
        $jsonData[] = json_decode($data, true);
    }

    $combinedData = array_reduce($jsonData, function ($acc, $curr) {
        return array_merge($acc, $curr);
    }, []);

    return $combinedData;
}

function addToJson($filepath, $param, $value) {
    $file = file_get_contents($filepath);
    $data = json_decode($file, true);

    $data[$param] = $value;

    $stringToWrite = json_encode($data, JSON_PRETTY_PRINT);
    file_put_contents($filepath, $stringToWrite);
}

function addToArray($filepath, $param, $value) {
    // Check if file exists
    if (!file_exists($filepath)) {
        $data = [];
    } else {
        $file = file_get_contents($filepath);
        $data = json_decode($file, true) ?? []; // Ensure it's an array
    }

    // If the parameter exists and is an array, append to it
    if (isset($data[$param]) && is_array($data[$param])) {
        $data[$param][] = $value;
    } else {
        $data[$param] = [$value]; // Convert to an array and add the value
    }

    // Write back to file
    $stringToWrite = json_encode($data, JSON_PRETTY_PRINT);
    file_put_contents($filepath, $stringToWrite);
}

function makeuniq($numChars) {
    $ID = "";
    $characters = "123456789";

    for ($i = 0; $i < $numChars; $i++) {
        $ID .= $characters[rand(0, strlen($characters) - 1)];
    }

    return $ID;
}

function stringToJsonObject($input) {
    $jsonObject = [];
    $inputString = strval($input);

    $pairs = explode('&', $inputString);
    foreach ($pairs as $pair) {
        list($key, $value) = explode('=', $pair, 2);
        $jsonObject[$key] = is_numeric($value) ? (float)$value : $value;
    }

    return $jsonObject;
}
