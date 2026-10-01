const fs = require("fs");
const path = require("path");
const { MongoClient } = require("mongodb");

const folderPath = "./"; // Change to your root folder path
const mongoUri = "mongodb://localhost:27017"; // Change if needed
const dbName = "Dx2"; // Change to your database name
const collectionName = "dramas"; // Single collection for all data

async function insertJsonFiles() {
    const client = new MongoClient(mongoUri);
    try {
        await client.connect();
        const db = client.db(dbName);
        const collection = db.collection(collectionName);

        async function processDirectory(directory) {
            const entries = fs.readdirSync(directory, { withFileTypes: true });

            for (const entry of entries) {
                const fullPath = path.join(directory, entry.name);

                if (entry.isDirectory()) {
                    await processDirectory(fullPath);
                } else if (entry.isFile() && entry.name.endsWith(".json")) {
                    const data = JSON.parse(fs.readFileSync(fullPath, "utf8"));

                    // Get relative path and remove ".json" extension
                    let relativePath = path.relative(folderPath, fullPath).replace(/\\/g, "/");
                    relativePath = relativePath.replace(/\.json$/, ""); // Remove .json extension

                    const document = {
                        path: relativePath, // Store folder structure without .json extension
                        data: data,
                    };

                    await collection.insertOne(document);
                    console.log(`Inserted ${entry.name} from ${relativePath}`);
                }
            }
        }

        await processDirectory(folderPath);
    } catch (error) {
        console.error("Error:", error);
    } finally {
        await client.close();
    }
}

insertJsonFiles();
