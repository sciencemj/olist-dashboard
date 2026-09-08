CREATE DATABASE IF NOT EXISTS olist;
USE olist;

-- 1. customers
DROP TABLE IF EXISTS raw_customers;

CREATE TABLE raw_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(20),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_customers_dataset.csv'
INTO TABLE raw_customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 2. orders
DROP TABLE IF EXISTS raw_orders;

CREATE TABLE raw_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp VARCHAR(30),
    order_approved_at VARCHAR(30),
    order_delivered_carrier_date VARCHAR(30),
    order_delivered_customer_date VARCHAR(30),
    order_estimated_delivery_date VARCHAR(30)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_orders_dataset.csv'
INTO TABLE raw_orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 3. order items
DROP TABLE IF EXISTS raw_order_items;

CREATE TABLE raw_order_items (
    order_id VARCHAR(50),
    order_item_id VARCHAR(20),
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date VARCHAR(30),
    price VARCHAR(30),
    freight_value VARCHAR(30)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_order_items_dataset.csv'
INTO TABLE raw_order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 4. payments
DROP TABLE IF EXISTS raw_order_payments;

CREATE TABLE raw_order_payments (
    order_id VARCHAR(50),
    payment_sequential VARCHAR(20),
    payment_type VARCHAR(50),
    payment_installments VARCHAR(20),
    payment_value VARCHAR(30)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_order_payments_dataset.csv'
INTO TABLE raw_order_payments
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 5. reviews
DROP TABLE IF EXISTS raw_order_reviews;

CREATE TABLE raw_order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score VARCHAR(10),
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date VARCHAR(30),
    review_answer_timestamp VARCHAR(30)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_order_reviews_dataset.csv'
INTO TABLE raw_order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 6. products
DROP TABLE IF EXISTS raw_products;

CREATE TABLE raw_products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_length VARCHAR(20),
    product_description_length VARCHAR(20),
    product_photos_qty VARCHAR(20),
    product_weight_g VARCHAR(30),
    product_length_cm VARCHAR(30),
    product_height_cm VARCHAR(30),
    product_width_cm VARCHAR(30)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_products_dataset.csv'
INTO TABLE raw_products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 7. sellers
DROP TABLE IF EXISTS raw_sellers;

CREATE TABLE raw_sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(20),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_sellers_dataset.csv'
INTO TABLE raw_sellers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 8. geolocation
DROP TABLE IF EXISTS raw_geolocation;

CREATE TABLE raw_geolocation (
    geolocation_zip_code_prefix VARCHAR(20),
    geolocation_lat VARCHAR(30),
    geolocation_lng VARCHAR(30),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/olist_geolocation_dataset.csv'
INTO TABLE raw_geolocation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 9. category translation
DROP TABLE IF EXISTS raw_category_translation;

CREATE TABLE raw_category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

LOAD DATA LOCAL INFILE '/Users/sciencemj/dev/olist-dashboard/data/product_category_name_translation.csv'
INTO TABLE raw_category_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- row count check
SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM raw_customers
UNION ALL
SELECT 'raw_orders', COUNT(*) FROM raw_orders
UNION ALL
SELECT 'raw_order_items', COUNT(*) FROM raw_order_items
UNION ALL
SELECT 'raw_order_payments', COUNT(*) FROM raw_order_payments
UNION ALL
SELECT 'raw_order_reviews', COUNT(*) FROM raw_order_reviews
UNION ALL
SELECT 'raw_products', COUNT(*) FROM raw_products
UNION ALL
SELECT 'raw_sellers', COUNT(*) FROM raw_sellers
UNION ALL
SELECT 'raw_geolocation', COUNT(*) FROM raw_geolocation
UNION ALL
SELECT 'raw_category_translation', COUNT(*) FROM raw_category_translation;