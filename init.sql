CREATE DATABASE IF NOT EXISTS bakeshop;

USE bakeshop;

CREATE TABLE IF NOT EXISTS products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10,2) NOT NULL,
    quantity INT DEFAULT 0
);

INSERT INTO products (product_name, category, price, quantity) VALUES
('Chocolate Cake', 'Cakes', 1500.00, 10),
('Vanilla Cake', 'Cakes', 1300.00, 8),
('Chocolate Donut', 'Donuts', 250.00, 20),
('Chicken Patties', 'Snacks', 180.00, 15),
('Blueberry Muffin', 'Muffins', 300.00, 12);