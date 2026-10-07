-- =====================================================================
-- Olist Brazilian E-Commerce Analytics Database
-- File: 01_schema_setup.sql
-- Description: DDL schema definition with primary keys, foreign keys, 
--              and index optimization for e-commerce performance analysis.
-- =====================================================================

-- Step 1: Create Database & Set Context
CREATE DATABASE IF NOT EXISTS olist_ecommerce;
USE olist_ecommerce;

-- Step 2: Drop existing tables (in reverse foreign-key dependency order)
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_category_translation;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS geolocation;

-- ---------------------------------------------------------------------
-- 1. Customers Table
-- Note: customer_id is a unique per-order identifier;
--       customer_unique_id identifies the actual unique person across orders.
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id VARCHAR(32) NOT NULL,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(5),
    PRIMARY KEY (customer_id),
    INDEX idx_customer_unique (customer_unique_id),
    INDEX idx_customer_state (customer_state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 2. Sellers Table
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id VARCHAR(32) NOT NULL,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(5),
    PRIMARY KEY (seller_id),
    INDEX idx_seller_state (seller_state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 3. Product Category Name Translation
-- ---------------------------------------------------------------------
CREATE TABLE product_category_translation (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 4. Products Table
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id VARCHAR(32) NOT NULL,
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    PRIMARY KEY (product_id),
    INDEX idx_product_category (product_category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 5. Orders Table (Central Fact entity)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id VARCHAR(32) NOT NULL,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    PRIMARY KEY (order_id),
    INDEX idx_customer (customer_id),
    INDEX idx_purchase_date (order_purchase_timestamp),
    INDEX idx_delivered_customer (order_delivered_customer_date),
    INDEX idx_status (order_status),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 6. Order Items Table
-- Granularity: One row per item inside an order
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date DATETIME,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    freight_value DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_product (product_id),
    INDEX idx_seller (seller_id),
    CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_items_seller FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 7. Order Payments Table
-- Granularity: One row per payment split/installment
-- ---------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id VARCHAR(32) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50) NOT NULL,
    payment_installments INT NOT NULL DEFAULT 1,
    payment_value DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (order_id, payment_sequential),
    INDEX idx_payment_type (payment_type),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 8. Order Reviews Table
-- ---------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id VARCHAR(32) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    review_score TINYINT NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_review_order (order_id),
    INDEX idx_review_score (review_score),
    CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 9. Geolocation Table (Optional lookup for spatial maps)
-- ---------------------------------------------------------------------
CREATE TABLE geolocation (
    geolocation_zip_code_prefix INT,
    geolocation_lat DECIMAL(10, 8),
    geolocation_lng DECIMAL(11, 8),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5),
    INDEX idx_geo_zip (geolocation_zip_code_prefix)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
