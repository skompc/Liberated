<?php

function getNumbersAfterQuest($questNumber) {
    // Read the file into an array of lines
    $lines = file("../data/quest_order.txt", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    
    if ($lines === false) {
        return null; // Return null if the file can't be read
    }

    // Loop through each line and search for the quest number in the first position
    foreach ($lines as $index => $line) {
        // Remove trailing comma and split into an array
        $numbers = array_filter(array_map('trim', explode(',', rtrim($line, ','))));

        // Ensure the array is not empty before accessing elements
        if (empty($numbers)) {
            continue;
        }

        $firstNumber = $numbers[0]; // Get the first number

        if ($firstNumber == $questNumber) { // Using == to allow integer comparisons
            // If there is a next line
            if (isset($lines[$index + 1])) {
                $nextLine = $lines[$index + 1];

                // Process the next line
                $nextNumbers = array_filter(array_map('trim', explode(',', rtrim($nextLine, ','))));

                // If the next line is just "0", return [10001]
                if (count($nextNumbers) === 1 && $nextNumbers[0] === "0") {
                    return [10001];
                }

                return $nextNumbers; // Otherwise, return the numbers from the next line
            }
            break; // No next line available
        }
    }

    return null; // Return null if the quest number was not found or no next line
}

function updateQuests($currentQuestNumber) {
    $jsonFilePath = "../saves/players/0/map.json";

    // Read the JSON file
    $jsonData = json_decode(file_get_contents("../saves/players/0/map.json"), true);
    
    if ($jsonData === null) {
        return false; // Return false if the JSON file could not be decoded
    }

    // Loop through each dungeon entry
    foreach ($jsonData['dngs'] as &$dng) {
        // Loop through each quest in the dungeon's quest list
        foreach ($dng['qsts'] as &$qst) {
            // If the quest's ID matches the current quest number, set "is_clear" to true
            if ($qst['id'] == $currentQuestNumber) {
                $qst['is_clear'] = true;
            }

            $questsArray = getNumbersAfterQuest($currentQuestNumber);

            // Check if the quest ID is in the input array, if so, update "is_opn" and "is_lck"
            if (in_array($qst['id'], $questsArray)) {
                $qst['is_opn'] = true;
                $qst['is_lck'] = false;
            }
        }
    }

    // Convert the updated data back to JSON
    $updatedJsonData = json_encode($jsonData, JSON_PRETTY_PRINT);

    // Save the updated JSON to the file
    if (file_put_contents($jsonFilePath, $updatedJsonData) !== false) {
        return true; // Return true if the file was updated successfully
    }

    return false; // Return false if the file could not be written
}

