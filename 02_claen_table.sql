-- =====================================================================
-- 02. raw_* -> clean_*
--   - 빈 문자열 -> NULL
--   - VARCHAR -> DATETIME / DECIMAL / UNSIGNED 캐스팅
--   - 문자열 정규화(TRIM, 도시명 소문자, 주 대문자)
--   - 중복 제거(reviews, geolocation)
--   - CTAS 후 PK / 인덱스 부여
-- 실행: mysql -u <user> -p olist < 02_claen_table.sql
-- 사전 조건: 01_raw_data.sql 로 raw_* 적재 완료. MySQL 8.0+ (윈도우 함수 사용)
-- =====================================================================

USE olist;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';


-- ---------------------------------------------------------------------
-- 1. clean_customers
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_customers;

CREATE TABLE clean_customers AS
SELECT
    NULLIF(TRIM(customer_id), '')                          AS customer_id,
    NULLIF(TRIM(customer_unique_id), '')                   AS customer_unique_id,
    CAST(NULLIF(TRIM(customer_zip_code_prefix), '') AS UNSIGNED) AS customer_zip_code_prefix,
    LOWER(NULLIF(TRIM(customer_city), ''))                 AS customer_city,
    UPPER(NULLIF(TRIM(customer_state), ''))                AS customer_state
FROM raw_customers;

ALTER TABLE clean_customers
    MODIFY customer_id        VARCHAR(50) NOT NULL,
    MODIFY customer_unique_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (customer_id),
    ADD KEY idx_cust_unique (customer_unique_id),
    ADD KEY idx_cust_state (customer_state);


-- ---------------------------------------------------------------------
-- 2. clean_orders
--   배송 리드타임 / 지연일수는 대시보드에서 매번 쓰므로 여기서 미리 계산
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_orders;

CREATE TABLE clean_orders AS
SELECT
    NULLIF(TRIM(order_id), '')                                          AS order_id,
    NULLIF(TRIM(customer_id), '')                                       AS customer_id,
    LOWER(NULLIF(TRIM(order_status), ''))                               AS order_status,
    CAST(NULLIF(TRIM(order_purchase_timestamp), '') AS DATETIME)        AS order_purchase_timestamp,
    CAST(NULLIF(TRIM(order_approved_at), '') AS DATETIME)               AS order_approved_at,
    CAST(NULLIF(TRIM(order_delivered_carrier_date), '') AS DATETIME)    AS order_delivered_carrier_date,
    CAST(NULLIF(TRIM(order_delivered_customer_date), '') AS DATETIME)   AS order_delivered_customer_date,
    CAST(NULLIF(TRIM(order_estimated_delivery_date), '') AS DATETIME)   AS order_estimated_delivery_date,
    -- 파생: 구매 -> 고객 수령까지 실제 소요일
    DATEDIFF(
        CAST(NULLIF(TRIM(order_delivered_customer_date), '') AS DATETIME),
        CAST(NULLIF(TRIM(order_purchase_timestamp), '') AS DATETIME)
    )                                                                   AS delivery_days,
    -- 파생: 예상일 대비 지연일수 (양수 = 늦음, 음수 = 빠름)
    DATEDIFF(
        CAST(NULLIF(TRIM(order_delivered_customer_date), '') AS DATETIME),
        CAST(NULLIF(TRIM(order_estimated_delivery_date), '') AS DATETIME)
    )                                                                   AS delivery_delay_days
FROM raw_orders;

ALTER TABLE clean_orders
    MODIFY order_id    VARCHAR(50) NOT NULL,
    MODIFY customer_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (order_id),
    ADD KEY idx_orders_customer (customer_id),
    ADD KEY idx_orders_purchase (order_purchase_timestamp),
    ADD KEY idx_orders_status (order_status);


-- ---------------------------------------------------------------------
-- 3. clean_order_items
--   PK = (order_id, order_item_id) 복합키
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_order_items;

CREATE TABLE clean_order_items AS
SELECT
    NULLIF(TRIM(order_id), '')                                    AS order_id,
    CAST(NULLIF(TRIM(order_item_id), '') AS UNSIGNED)             AS order_item_id,
    NULLIF(TRIM(product_id), '')                                  AS product_id,
    NULLIF(TRIM(seller_id), '')                                   AS seller_id,
    CAST(NULLIF(TRIM(shipping_limit_date), '') AS DATETIME)       AS shipping_limit_date,
    CAST(NULLIF(TRIM(price), '') AS DECIMAL(10, 2))               AS price,
    CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10, 2))       AS freight_value,
    CAST(NULLIF(TRIM(price), '') AS DECIMAL(10, 2))
      + CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10, 2))   AS item_total
FROM raw_order_items;

ALTER TABLE clean_order_items
    MODIFY order_id      VARCHAR(50) NOT NULL,
    MODIFY order_item_id INT UNSIGNED NOT NULL,
    ADD PRIMARY KEY (order_id, order_item_id),
    ADD KEY idx_items_product (product_id),
    ADD KEY idx_items_seller (seller_id);


-- ---------------------------------------------------------------------
-- 4. clean_order_payments
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_order_payments;

CREATE TABLE clean_order_payments AS
SELECT
    NULLIF(TRIM(order_id), '')                                AS order_id,
    CAST(NULLIF(TRIM(payment_sequential), '') AS UNSIGNED)    AS payment_sequential,
    LOWER(NULLIF(TRIM(payment_type), ''))                     AS payment_type,
    CAST(NULLIF(TRIM(payment_installments), '') AS UNSIGNED)  AS payment_installments,
    CAST(NULLIF(TRIM(payment_value), '') AS DECIMAL(10, 2))   AS payment_value
FROM raw_order_payments;

ALTER TABLE clean_order_payments
    MODIFY order_id           VARCHAR(50) NOT NULL,
    MODIFY payment_sequential INT UNSIGNED NOT NULL,
    ADD PRIMARY KEY (order_id, payment_sequential),
    ADD KEY idx_pay_type (payment_type);


-- ---------------------------------------------------------------------
-- 5. clean_order_reviews
--   review_id 가 중복으로 들어있음 -> 최신 응답 1건만 남김
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_order_reviews;

CREATE TABLE clean_order_reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM (
    SELECT
        NULLIF(TRIM(review_id), '')                                  AS review_id,
        NULLIF(TRIM(order_id), '')                                   AS order_id,
        CAST(NULLIF(TRIM(review_score), '') AS UNSIGNED)             AS review_score,
        NULLIF(TRIM(review_comment_title), '')                       AS review_comment_title,
        NULLIF(TRIM(review_comment_message), '')                     AS review_comment_message,
        CAST(NULLIF(TRIM(review_creation_date), '') AS DATETIME)     AS review_creation_date,
        CAST(NULLIF(TRIM(review_answer_timestamp), '') AS DATETIME)  AS review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(TRIM(review_id), '')
            ORDER BY CAST(NULLIF(TRIM(review_answer_timestamp), '') AS DATETIME) DESC
        ) AS rn
    FROM raw_order_reviews
) t
WHERE rn = 1;

ALTER TABLE clean_order_reviews
    MODIFY review_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (review_id),
    ADD KEY idx_rev_order (order_id),
    ADD KEY idx_rev_score (review_score);


-- ---------------------------------------------------------------------
-- 6. clean_products
--   영문 카테고리명 조인. 번역 없으면 원문 유지, 그것도 없으면 'unknown'
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_products;

CREATE TABLE clean_products AS
SELECT
    NULLIF(TRIM(p.product_id), '')                                       AS product_id,
    COALESCE(
        NULLIF(TRIM(t.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'unknown'
    )                                                                    AS product_category,
    NULLIF(TRIM(p.product_category_name), '')                            AS product_category_pt,
    CAST(NULLIF(TRIM(p.product_name_length), '') AS UNSIGNED)            AS product_name_length,
    CAST(NULLIF(TRIM(p.product_description_length), '') AS UNSIGNED)     AS product_description_length,
    CAST(NULLIF(TRIM(p.product_photos_qty), '') AS UNSIGNED)             AS product_photos_qty,
    CAST(NULLIF(TRIM(p.product_weight_g), '') AS DECIMAL(10, 2))         AS product_weight_g,
    CAST(NULLIF(TRIM(p.product_length_cm), '') AS DECIMAL(10, 2))        AS product_length_cm,
    CAST(NULLIF(TRIM(p.product_height_cm), '') AS DECIMAL(10, 2))        AS product_height_cm,
    CAST(NULLIF(TRIM(p.product_width_cm), '') AS DECIMAL(10, 2))         AS product_width_cm,
    CAST(NULLIF(TRIM(p.product_length_cm), '') AS DECIMAL(10, 2))
      * CAST(NULLIF(TRIM(p.product_height_cm), '') AS DECIMAL(10, 2))
      * CAST(NULLIF(TRIM(p.product_width_cm), '') AS DECIMAL(10, 2))     AS product_volume_cm3
FROM raw_products p
LEFT JOIN raw_category_translation t
       ON TRIM(p.product_category_name) = TRIM(t.product_category_name);

ALTER TABLE clean_products
    MODIFY product_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (product_id),
    ADD KEY idx_prod_category (product_category);


-- ---------------------------------------------------------------------
-- 7. clean_sellers
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_sellers;

CREATE TABLE clean_sellers AS
SELECT
    NULLIF(TRIM(seller_id), '')                                   AS seller_id,
    CAST(NULLIF(TRIM(seller_zip_code_prefix), '') AS UNSIGNED)    AS seller_zip_code_prefix,
    LOWER(NULLIF(TRIM(seller_city), ''))                          AS seller_city,
    UPPER(NULLIF(TRIM(seller_state), ''))                         AS seller_state
FROM raw_sellers;

ALTER TABLE clean_sellers
    MODIFY seller_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (seller_id),
    ADD KEY idx_seller_state (seller_state);


-- ---------------------------------------------------------------------
-- 8. clean_geolocation
--   원본은 zip 당 수천 행. zip 1행으로 축약(좌표 평균 + 최빈 도시/주)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_geolocation;

CREATE TABLE clean_geolocation AS
SELECT
    c.zip_code_prefix,
    a.lat,
    a.lng,
    c.city,
    c.state
FROM (
    -- zip 별 좌표 평균
    SELECT
        CAST(NULLIF(TRIM(geolocation_zip_code_prefix), '') AS UNSIGNED)  AS zip_code_prefix,
        ROUND(AVG(CAST(NULLIF(TRIM(geolocation_lat), '') AS DECIMAL(11, 8))), 8) AS lat,
        ROUND(AVG(CAST(NULLIF(TRIM(geolocation_lng), '') AS DECIMAL(11, 8))), 8) AS lng
    FROM raw_geolocation
    GROUP BY 1
) a
JOIN (
    -- zip 별 최빈 (도시, 주)
    SELECT zip_code_prefix, city, state
    FROM (
        SELECT
            CAST(NULLIF(TRIM(geolocation_zip_code_prefix), '') AS UNSIGNED) AS zip_code_prefix,
            LOWER(NULLIF(TRIM(geolocation_city), ''))                       AS city,
            UPPER(NULLIF(TRIM(geolocation_state), ''))                      AS state,
            ROW_NUMBER() OVER (
                PARTITION BY CAST(NULLIF(TRIM(geolocation_zip_code_prefix), '') AS UNSIGNED)
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM raw_geolocation
        GROUP BY 1, 2, 3
    ) r
    WHERE rn = 1
) c ON c.zip_code_prefix = a.zip_code_prefix
WHERE c.zip_code_prefix IS NOT NULL;

ALTER TABLE clean_geolocation
    MODIFY zip_code_prefix INT UNSIGNED NOT NULL,
    ADD PRIMARY KEY (zip_code_prefix),
    ADD KEY idx_geo_state (state);


-- =====================================================================
-- 검증
-- =====================================================================

-- 1) 행 수 비교 (reviews / geolocation 은 중복 제거로 줄어드는 게 정상)
SELECT 'customers'   AS tbl, (SELECT COUNT(*) FROM raw_customers)   AS raw_rows, COUNT(*) AS clean_rows FROM clean_customers
UNION ALL SELECT 'orders',        (SELECT COUNT(*) FROM raw_orders),        COUNT(*) FROM clean_orders
UNION ALL SELECT 'order_items',   (SELECT COUNT(*) FROM raw_order_items),   COUNT(*) FROM clean_order_items
UNION ALL SELECT 'payments',      (SELECT COUNT(*) FROM raw_order_payments),COUNT(*) FROM clean_order_payments
UNION ALL SELECT 'reviews',       (SELECT COUNT(*) FROM raw_order_reviews), COUNT(*) FROM clean_order_reviews
UNION ALL SELECT 'products',      (SELECT COUNT(*) FROM raw_products),      COUNT(*) FROM clean_products
UNION ALL SELECT 'sellers',       (SELECT COUNT(*) FROM raw_sellers),       COUNT(*) FROM clean_sellers
UNION ALL SELECT 'geolocation',   (SELECT COUNT(*) FROM raw_geolocation),   COUNT(*) FROM clean_geolocation;

-- 2) 캐스팅 실패(원본은 값이 있는데 NULL 이 된 경우) 점검
SELECT
    SUM(order_purchase_timestamp IS NULL)       AS null_purchase_ts,
    SUM(order_delivered_customer_date IS NULL)  AS null_delivered,  -- 미배송 주문이라 정상적으로 NULL
    SUM(delivery_days < 0)                      AS negative_delivery_days
FROM clean_orders;

SELECT
    SUM(price IS NULL)         AS null_price,
    SUM(price <= 0)            AS non_positive_price,
    SUM(freight_value IS NULL) AS null_freight
FROM clean_order_items;

-- 3) 참조 무결성 (고아 행 = 0 이어야 정상)
SELECT COUNT(*) AS orphan_orders
FROM clean_orders o LEFT JOIN clean_customers c USING (customer_id)
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS orphan_items
FROM clean_order_items i LEFT JOIN clean_orders o USING (order_id)
WHERE o.order_id IS NULL;
