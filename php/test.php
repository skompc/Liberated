<?php
try {
    $client = new MongoDB\Driver\Manager("mongodb://localhost:27017");
    echo "MongoDB connection successful!";
} catch (Exception $e) {
    echo "MongoDB connection failed: " . $e->getMessage();
}
?>