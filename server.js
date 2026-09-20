const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// MySQL connection (values now come from environment variables so the
// same image works locally, in docker-compose, and on EC2 without
// hardcoding credentials).
const dbConfig = {
    host: process.env.DB_HOST || "localhost",
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "bakeshop"
};

let db;

function connectWithRetry() {
    db = mysql.createConnection(dbConfig);

    db.connect((err) => {
        if (err) {
            console.log("MySQL connection failed, retrying in 5s:", err.message);
            setTimeout(connectWithRetry, 5000);
            return;
        }
        console.log("Connected to MySQL database");
    });

    db.on("error", (err) => {
        console.log("MySQL connection lost, reconnecting:", err.message);
        if (err.code === "PROTOCOL_CONNECTION_LOST") {
            connectWithRetry();
        }
    });
}

connectWithRetry();

// ================= HEALTH CHECK =================
// Used by the Dockerfile HEALTHCHECK and can also be hit by a load
// balancer / uptime check on EC2.
app.get("/health", (req, res) => {
    res.status(200).json({ status: "ok" });
});

// ================= CREATE =================

app.post("/products", (req, res) => {
    const { product_name, category, price, quantity } = req.body;

    const sql = `
        INSERT INTO products (product_name, category, price, quantity)
        VALUES (?, ?, ?, ?)
    `;

    db.query(
        sql,
        [product_name, category, price, quantity],
        (err, result) => {
            if (err) {
                return res.status(500).json({
                    error: err.message
                });
            }

            res.status(201).json({
                message: "Product created successfully",
                productId: result.insertId
            });
        }
    );
});

// ================= READ ALL =================

app.get("/products", (req, res) => {
    const sql = "SELECT * FROM products";

    db.query(sql, (err, results) => {
        if (err) {
            return res.status(500).json({
                error: err.message
            });
        }

        res.json(results);
    });
});

// ================= READ ONE =================

app.get("/products/:id", (req, res) => {
    const id = req.params.id;

    const sql = "SELECT * FROM products WHERE id = ?";

    db.query(sql, [id], (err, results) => {
        if (err) {
            return res.status(500).json({
                error: err.message
            });
        }

        if (results.length === 0) {
            return res.status(404).json({
                message: "Product not found"
            });
        }

        res.json(results[0]);
    });
});

// ================= UPDATE =================

app.put("/products/:id", (req, res) => {
    const id = req.params.id;
    const { product_name, category, price, quantity } = req.body;

    const sql = `
        UPDATE products
        SET product_name = ?,
            category = ?,
            price = ?,
            quantity = ?
        WHERE id = ?
    `;

    db.query(
        sql,
        [product_name, category, price, quantity, id],
        (err, result) => {
            if (err) {
                return res.status(500).json({
                    error: err.message
                });
            }

            if (result.affectedRows === 0) {
                return res.status(404).json({
                    message: "Product not found"
                });
            }

            res.json({
                message: "Product updated successfully"
            });
        }
    );
});

// ================= DELETE =================

app.delete("/products/:id", (req, res) => {
    const id = req.params.id;

    const sql = "DELETE FROM products WHERE id = ?";

    db.query(sql, [id], (err, result) => {
        if (err) {
            return res.status(500).json({
                error: err.message
            });
        }

        if (result.affectedRows === 0) {
            return res.status(404).json({
                message: "Product not found"
            });
        }

        res.json({
            message: "Product deleted successfully"
        });
    });
});

// Start server - bind to 0.0.0.0 so it's reachable from outside the container
app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on port ${PORT}`);
});
