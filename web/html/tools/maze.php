<?php

function makeMaze($rows, $cols){
    // --- Constants ---
    define('DOOR_N', 1);
    define('DOOR_E', 2);
    define('DOOR_S', 4);
    define('DOOR_W', 8);

    define('WALL_N', 16);
    define('WALL_E', 32);
    define('WALL_S', 64);
    define('WALL_W', 128);

    define('NORMAL_FLOOR', 524288);
    define('WALK', 8589934592);
    define('BATTLE', 17179869184);
    define('BOSS_ROOM', 34359738368);

    // Probability settings
    $biasProbability = 0.7;          // DFS bias for hallways (continue in same direction)
    $extraDoorChance   = 0.2;          // Chance to add an extra door connection (if no hallway exists)
    $removeDoorChance  = 0.2;          // Chance to remove a door connection later
    $battleChance      = 30;           // Percentage chance (0-100) for battle encounters

    // --- Data Structure ---
    // Each cell tracks two sets of flags for each side:
    //   hall_<dir>: true if a hallway (spanning tree passage) exists.
    //   door_<dir>: true if an extra door connection exists.
    // Also, a 'battle' flag is stored.
    $mazeCells = [];
    for ($r = 0; $r < $rows; $r++) {
        for ($c = 0; $c < $cols; $c++) {
            $mazeCells[$r][$c] = [
                'hall_N' => false,
                'hall_E' => false,
                'hall_S' => false,
                'hall_W' => false,
                'door_N' => false,
                'door_E' => false,
                'door_S' => false,
                'door_W' => false,
                'battle'   => false
            ];
        }
    }

    // --- Connectivity Check ---
    // Returns true if all cells are reachable from (0,0) via any connection.
    function isConnected($mazeCells, $rows, $cols) {
        $visited = array_fill(0, $rows, array_fill(0, $cols, false));
        $stack = [];
        $stack[] = [0, 0];
        $visited[0][0] = true;
        $count = 1;
        
        $directions = [
            'N' => [-1, 0],
            'E' => [0, 1],
            'S' => [1, 0],
            'W' => [0, -1]
        ];
        
        while (!empty($stack)) {
            list($r, $c) = array_pop($stack);
            foreach ($directions as $dir => $delta) {
                if ($mazeCells[$r][$c]['hall_'.$dir] || $mazeCells[$r][$c]['door_'.$dir]) {
                    $nr = $r + $delta[0];
                    $nc = $c + $delta[1];
                    if ($nr >= 0 && $nr < $rows && $nc >= 0 && $nc < $cols && !$visited[$nr][$nc]) {
                        $visited[$nr][$nc] = true;
                        $stack[] = [$nr, $nc];
                        $count++;
                    }
                }
            }
        }
        return ($count === $rows * $cols);
    }

    // --- Step 1: Generate Main Hallways (Spanning Tree via DFS with Bias) ---
    $visitedDFS = [];
    for ($r = 0; $r < $rows; $r++) {
        for ($c = 0; $c < $cols; $c++) {
            $visitedDFS[$r][$c] = false;
        }
    }
    $stack = [];
    $visitedDFS[0][0] = true;
    $stack[] = ['r' => 0, 'c' => 0, 'dir' => null];

    while (!empty($stack)) {
        $current = end($stack);
        $r = $current['r'];
        $c = $current['c'];
        
        $neighbors = [];
        if ($r > 0 && !$visitedDFS[$r-1][$c]) {
            $neighbors[] = ['r' => $r-1, 'c' => $c, 'dir' => 'N'];
        }
        if ($r < $rows - 1 && !$visitedDFS[$r+1][$c]) {
            $neighbors[] = ['r' => $r+1, 'c' => $c, 'dir' => 'S'];
        }
        if ($c > 0 && !$visitedDFS[$r][$c-1]) {
            $neighbors[] = ['r' => $r, 'c' => $c-1, 'dir' => 'W'];
        }
        if ($c < $cols - 1 && !$visitedDFS[$r][$c+1]) {
            $neighbors[] = ['r' => $r, 'c' => $c+1, 'dir' => 'E'];
        }
        
        if (!empty($neighbors)) {
            $chosen = null;
            // Bias: if an incoming direction exists, prefer continuing that way.
            if ($current['dir'] !== null) {
                foreach ($neighbors as $n) {
                    if ($n['dir'] === $current['dir']) {
                        if (mt_rand(0, 1000) / 1000 < $biasProbability) {
                            $chosen = $n;
                            break;
                        }
                        break;
                    }
                }
            }
            if ($chosen === null) {
                $chosen = $neighbors[array_rand($neighbors)];
            }
            // Carve a hallway between current cell and chosen neighbor.
            switch ($chosen['dir']) {
                case 'N':
                    $mazeCells[$r][$c]['hall_N'] = true;
                    $mazeCells[$chosen['r']][$chosen['c']]['hall_S'] = true;
                    break;
                case 'S':
                    $mazeCells[$r][$c]['hall_S'] = true;
                    $mazeCells[$chosen['r']][$chosen['c']]['hall_N'] = true;
                    break;
                case 'E':
                    $mazeCells[$r][$c]['hall_E'] = true;
                    $mazeCells[$chosen['r']][$chosen['c']]['hall_W'] = true;
                    break;
                case 'W':
                    $mazeCells[$r][$c]['hall_W'] = true;
                    $mazeCells[$chosen['r']][$chosen['c']]['hall_E'] = true;
                    break;
            }
            $visitedDFS[$chosen['r']][$chosen['c']] = true;
            $stack[] = ['r' => $chosen['r'], 'c' => $chosen['c'], 'dir' => $chosen['dir']];
        } else {
            array_pop($stack);
        }
    }

    // --- Step 2: Add Extra Door Connections ---
    // For each adjacent cell pair (without a hallway) try to add a door.
    $directions = [
        'N' => [-1, 0],
        'E' => [0, 1],
        'S' => [1, 0],
        'W' => [0, -1]
    ];
    for ($r = 0; $r < $rows; $r++) {
        for ($c = 0; $c < $cols; $c++) {
            foreach ($directions as $dir => $delta) {
                $nr = $r + $delta[0];
                $nc = $c + $delta[1];
                if ($nr >= 0 && $nr < $rows && $nc >= 0 && $nc < $cols) {
                    // Only add a door if no hallway exists on that side.
                    if (!$mazeCells[$r][$c]['hall_'.$dir] && !$mazeCells[$r][$c]['door_'.$dir]) {
                        if (mt_rand(0, 1000) / 1000 < $extraDoorChance) {
                            $mazeCells[$r][$c]['door_'.$dir] = true;
                            switch ($dir) {
                                case 'N': $mazeCells[$nr][$nc]['door_S'] = true; break;
                                case 'S': $mazeCells[$nr][$nc]['door_N'] = true; break;
                                case 'E': $mazeCells[$nr][$nc]['door_W'] = true; break;
                                case 'W': $mazeCells[$nr][$nc]['door_E'] = true; break;
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Step 3: Randomly Remove Some Door Connections ---
    // Remove extra door connections if the maze remains connected.
    for ($r = 0; $r < $rows; $r++) {
        for ($c = 0; $c < $cols; $c++) {
            if ($c < $cols - 1 && $mazeCells[$r][$c]['door_E']) {
                if (mt_rand(0, 1000) / 1000 < $removeDoorChance) {
                    $original = $mazeCells[$r][$c]['door_E'];
                    $mazeCells[$r][$c]['door_E'] = false;
                    $backup = $mazeCells[$r][$c+1]['door_W'];
                    $mazeCells[$r][$c+1]['door_W'] = false;
                    if (!isConnected($mazeCells, $rows, $cols)) {
                        $mazeCells[$r][$c]['door_E'] = $original;
                        $mazeCells[$r][$c+1]['door_W'] = $backup;
                    }
                }
            }
            if ($r < $rows - 1 && $mazeCells[$r][$c]['door_S']) {
                if (mt_rand(0, 1000) / 1000 < $removeDoorChance) {
                    $original = $mazeCells[$r][$c]['door_S'];
                    $mazeCells[$r][$c]['door_S'] = false;
                    $backup = $mazeCells[$r+1][$c]['door_N'];
                    $mazeCells[$r+1][$c]['door_N'] = false;
                    if (!isConnected($mazeCells, $rows, $cols)) {
                        $mazeCells[$r][$c]['door_S'] = $original;
                        $mazeCells[$r+1][$c]['door_N'] = $backup;
                    }
                }
            }
        }
    }

    // --- Step 4: Assign Battle Encounters ---
    // For each cell (except the start at [0,0]) add a battle flag.
    for ($r = 0; $r < $rows; $r++) {
        for ($c = 0; $c < $cols; $c++) {
            if (!($r == 0 && $c == 0)) {
                if (mt_rand(0, 99) < $battleChance) {
                    $mazeCells[$r][$c]['battle'] = true;
                }
            }
        }
    }

    // --- Step 5: Choose a Random Boss Room (Not the Start) ---
    do {
        $bossR = mt_rand(0, $rows - 1);
        $bossC = mt_rand(0, $cols - 1);
    } while ($bossR == 0 && $bossC == 0);

    // --- Step 6: Override the Boss Room Cell ---
    // The boss room cell will have exactly one entrance (a door) and the other three sides will be walls.
    // First, compute valid entrance directions (only those that lead to a neighbor).
    $bossValidDirs = [];
    if ($bossR > 0)          { $bossValidDirs[] = 'N'; }
    if ($bossR < $rows - 1)  { $bossValidDirs[] = 'S'; }
    if ($bossC > 0)          { $bossValidDirs[] = 'W'; }
    if ($bossC < $cols - 1)  { $bossValidDirs[] = 'E'; }
    $bossDoorDir = $bossValidDirs[array_rand($bossValidDirs)];

    // Override the boss room cell: clear all hallway and door flags, then set one door.
    $mazeCells[$bossR][$bossC]['hall_N'] = false;
    $mazeCells[$bossR][$bossC]['hall_E'] = false;
    $mazeCells[$bossR][$bossC]['hall_S'] = false;
    $mazeCells[$bossR][$bossC]['hall_W'] = false;
    $mazeCells[$bossR][$bossC]['door_N'] = false;
    $mazeCells[$bossR][$bossC]['door_E'] = false;
    $mazeCells[$bossR][$bossC]['door_S'] = false;
    $mazeCells[$bossR][$bossC]['door_W'] = false;
    $mazeCells[$bossR][$bossC]['door_'.$bossDoorDir] = true;

    // Also, update the neighbor cell in the opposite direction to ensure the connection.
    // Remove any hallway on the neighbor side and force the door.
    switch ($bossDoorDir) {
        case 'N':
            $mazeCells[$bossR-1][$bossC]['hall_S'] = false;
            $mazeCells[$bossR-1][$bossC]['door_S'] = true;
            break;
        case 'S':
            $mazeCells[$bossR+1][$bossC]['hall_N'] = false;
            $mazeCells[$bossR+1][$bossC]['door_N'] = true;
            break;
        case 'E':
            $mazeCells[$bossR][$bossC+1]['hall_W'] = false;
            $mazeCells[$bossR][$bossC+1]['door_W'] = true;
            break;
        case 'W':
            $mazeCells[$bossR][$bossC-1]['hall_E'] = false;
            $mazeCells[$bossR][$bossC-1]['door_E'] = true;
            break;
    }

    // --- Step 7: Build Final Maze Representation ---
    // For each cell, start with the base (NORMAL_FLOOR + WALK). Then, for each side:
    //   - If a hallway exists, add 0 (hallways add no value).
    //   - Else if a door exists, add the door constant.
    //   - Otherwise, add the wall constant.
    // Finally, add BATTLE if set and BOSS_ROOM if this cell is the boss.
    $base = NORMAL_FLOOR + WALK;
    $maze = [];
    for ($r = 0; $r < $rows; $r++) {
        for ($c = 0; $c < $cols; $c++) {
            $unit = $base;
            // North side:
            if ($mazeCells[$r][$c]['hall_N']) {
                $unit += 0;
            } elseif ($mazeCells[$r][$c]['door_N']) {
                $unit += DOOR_N;
            } else {
                $unit += WALL_N;
            }
            // East side:
            if ($mazeCells[$r][$c]['hall_E']) {
                $unit += 0;
            } elseif ($mazeCells[$r][$c]['door_E']) {
                $unit += DOOR_E;
            } else {
                $unit += WALL_E;
            }
            // South side:
            if ($mazeCells[$r][$c]['hall_S']) {
                $unit += 0;
            } elseif ($mazeCells[$r][$c]['door_S']) {
                $unit += DOOR_S;
            } else {
                $unit += WALL_S;
            }
            // West side:
            if ($mazeCells[$r][$c]['hall_W']) {
                $unit += 0;
            } elseif ($mazeCells[$r][$c]['door_W']) {
                $unit += DOOR_W;
            } else {
                $unit += WALL_W;
            }
            if ($mazeCells[$r][$c]['battle']) {
                $unit += BATTLE;
            }
            // Add boss room flag if this cell is the chosen boss.
            if ($r == $bossR && $c == $bossC) {
                $unit += BOSS_ROOM;
            }
            $maze[] = $unit;
        }
    }

    // --- Prepare the Output Objects ---
    // Create an object (associative array) for maze.json contents.
    $mazeData = ["update" => []];
    foreach ($maze as $pos => $unit) {
        $mazeData["update"][] = ["unit" => $unit, "pos" => $pos];
    }

    // Create a string for maze.txt contents.
    $txtData = json_encode($maze, JSON_UNESCAPED_SLASHES);

    // Create an object for full.json contents.
    $fullUpdate = [];
    foreach ($maze as $pos => $unit) {
        // Check if this cell is the boss room (BOSS_ROOM flag is set).
        if (($unit & BOSS_ROOM) === BOSS_ROOM) {
            $newUnit = $unit - 34359738368 + 68719476736;
        } else {
            $newUnit = $unit + 1048576;
        }
        $fullUpdate[] = ["unit" => $newUnit, "pos" => $pos];
    }
    $fullData = ["update" => $fullUpdate];

    // Instead of writing to files, return an associative array containing the three outputs.
    return [
        "maze" => $mazeData,
        "txt"  => $txtData,
        "full" => $fullData
    ];
}
?>
