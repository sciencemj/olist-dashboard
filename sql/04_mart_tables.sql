-- =====================================================================
-- 04. clean_* -> mart_*  (BI 도구가 바로 붙는 층)
--   sql/03_add_foreign_keys.sql 실행 이후에 돌린다.
--
--   설계 원칙
--   1. 그레인을 고정한다. mart_orders 는 1행 = 주문 1건,
--      mart_order_items 는 1행 = 주문 품목 1건. 섞지 않는다.
--   2. 1:N 을 조인하지 않고 먼저 집계해서 붙인다. orders 에 payments 를
--      그냥 조인하면 결제 2건 이상인 주문 2,961건에서 행이 늘어나
--      결제총액이 27% 부풀려진다 (16,008,872 -> 20,308,134).
--   3. 사전 집계는 하지 않는다. 일별/월별 합계는 BI 도구의 GROUP BY 에
--      맡기고, 여기서는 필터 가능한 원자 단위를 넓게 펴서 제공한다.
--
--   BI 도구는 mart_* 만 바라보게 한다. raw_* / clean_* 은 노출하지 않는다.
--
-- 실행: mysql -u <user> -p olist < sql/04_mart_tables.sql
-- =====================================================================

USE olist;


-- ---------------------------------------------------------------------
-- 1. mart_orders
--    그레인: order_id 1건
--
--    주의: clean_order_reviews 는 review_id 기준으로 중복을 제거했기 때문에
--    order_id 는 여전히 중복될 수 있다 (리뷰 2건 이상인 주문 547건).
--    그래서 리뷰도 조인이 아니라 집계해서 붙인다.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart_orders;

CREATE TABLE mart_orders AS
SELECT
    o.order_id,

    -- 고객
    o.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.lat  AS customer_lat,
    g.lng  AS customer_lng,

    -- 주문 상태 / 시각
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- 날짜 파생 (BI 필터/축 용도)
    DATE(o.order_purchase_timestamp)                              AS purchase_date,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')           AS purchase_month,
    YEAR(o.order_purchase_timestamp)                              AS purchase_year,
    DAYOFWEEK(o.order_purchase_timestamp)                         AS purchase_dow,
    DAYNAME(o.order_purchase_timestamp)                           AS purchase_dayname,
    HOUR(o.order_purchase_timestamp)                              AS purchase_hour,

    -- 배송
    o.delivery_days,
    o.delivery_delay_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.delivery_delay_days > 0 THEN 1
        ELSE 0
    END                                                           AS is_late,
    CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END       AS is_delivered,

    -- 품목 집계
    COALESCE(i.item_count, 0)              AS item_count,
    COALESCE(i.distinct_product_count, 0)  AS distinct_product_count,
    COALESCE(i.distinct_seller_count, 0)   AS distinct_seller_count,
    i.product_amount,
    i.freight_amount,
    i.order_amount,

    -- 결제 집계
    COALESCE(p.payment_count, 0) AS payment_count,
    p.payment_amount,
    p.max_installments,
    pt.primary_payment_type,

    -- 리뷰 집계
    COALESCE(r.review_count, 0) AS review_count,
    r.review_score,
    r.first_review_date

FROM clean_orders o
JOIN clean_customers c
  ON c.customer_id = o.customer_id

-- 좌표는 FK 없이 zip prefix 로 붙인다. 매칭 없으면 NULL (customers 278행)
LEFT JOIN clean_geolocation g
  ON g.zip_code_prefix = c.customer_zip_code_prefix

LEFT JOIN (
    SELECT
        order_id,
        COUNT(*)                          AS item_count,
        COUNT(DISTINCT product_id)        AS distinct_product_count,
        COUNT(DISTINCT seller_id)         AS distinct_seller_count,
        SUM(price)                        AS product_amount,
        SUM(freight_value)                AS freight_amount,
        SUM(item_total)                   AS order_amount
    FROM clean_order_items
    GROUP BY order_id
) i ON i.order_id = o.order_id

LEFT JOIN (
    SELECT
        order_id,
        COUNT(*)                   AS payment_count,
        SUM(payment_value)         AS payment_amount,
        MAX(payment_installments)  AS max_installments
    FROM clean_order_payments
    GROUP BY order_id
) p ON p.order_id = o.order_id

-- 결제수단이 여러 개면 금액이 가장 큰 것을 대표값으로 삼는다
LEFT JOIN (
    SELECT order_id, payment_type AS primary_payment_type
    FROM (
        SELECT
            order_id,
            payment_type,
            ROW_NUMBER() OVER (
                PARTITION BY order_id ORDER BY SUM(payment_value) DESC
            ) AS rn
        FROM clean_order_payments
        GROUP BY order_id, payment_type
    ) t
    WHERE rn = 1
) pt ON pt.order_id = o.order_id

LEFT JOIN (
    SELECT
        order_id,
        COUNT(*)                       AS review_count,
        AVG(review_score)              AS review_score,
        MIN(review_creation_date)      AS first_review_date
    FROM clean_order_reviews
    WHERE order_id IS NOT NULL
    GROUP BY order_id
) r ON r.order_id = o.order_id;

ALTER TABLE mart_orders
    MODIFY order_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (order_id),
    ADD KEY idx_mo_date (purchase_date),
    ADD KEY idx_mo_month (purchase_month),
    ADD KEY idx_mo_state (customer_state),
    ADD KEY idx_mo_status (order_status),
    ADD KEY idx_mo_unique_cust (customer_unique_id);


-- ---------------------------------------------------------------------
-- 2. mart_order_items
--    그레인: (order_id, order_item_id) 1건
--
--    결제 컬럼은 넣지 않는다. 결제는 주문 단위라 품목 단위로 펴면
--    중복 합산된다. 결제 지표는 mart_orders 에서 본다.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart_order_items;

CREATE TABLE mart_order_items AS
SELECT
    i.order_id,
    i.order_item_id,

    -- 주문 (필터용으로 펴둔 값)
    o.order_status,
    o.order_purchase_timestamp,
    DATE(o.order_purchase_timestamp)                    AS purchase_date,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS purchase_month,
    YEAR(o.order_purchase_timestamp)                    AS purchase_year,
    o.delivery_days,
    o.delivery_delay_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.delivery_delay_days > 0 THEN 1
        ELSE 0
    END                                                 AS is_late,

    -- 고객
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    -- 판매자
    i.seller_id,
    s.seller_city,
    s.seller_state,

    -- 상품
    i.product_id,
    pr.product_category,
    pr.product_category_pt,
    pr.product_weight_g,
    pr.product_volume_cm3,
    pr.product_photos_qty,

    -- 금액 (이 테이블에서 합산해도 안전한 값)
    i.price,
    i.freight_value,
    i.item_total,
    i.shipping_limit_date

FROM clean_order_items i
JOIN clean_orders o     ON o.order_id   = i.order_id
JOIN clean_customers c  ON c.customer_id = o.customer_id
LEFT JOIN clean_products pr ON pr.product_id = i.product_id
LEFT JOIN clean_sellers  s  ON s.seller_id   = i.seller_id;

ALTER TABLE mart_order_items
    MODIFY order_id      VARCHAR(50) NOT NULL,
    MODIFY order_item_id INT UNSIGNED NOT NULL,
    ADD PRIMARY KEY (order_id, order_item_id),
    ADD KEY idx_moi_date (purchase_date),
    ADD KEY idx_moi_month (purchase_month),
    ADD KEY idx_moi_category (product_category),
    ADD KEY idx_moi_seller (seller_id),
    ADD KEY idx_moi_state (customer_state);


-- =====================================================================
-- 검증
--   그레인이 지켜졌고 fan-out 이 없는지 확인한다.
--   아래 4개 비교쌍이 전부 일치해야 정상이다.
-- =====================================================================

SELECT 'mart_orders 행수'      AS metric,
       (SELECT COUNT(*) FROM clean_orders)             AS expected,
       (SELECT COUNT(*) FROM mart_orders)              AS actual
UNION ALL
SELECT 'mart_order_items 행수',
       (SELECT COUNT(*) FROM clean_order_items),
       (SELECT COUNT(*) FROM mart_order_items)
UNION ALL
SELECT '결제총액',
       (SELECT ROUND(SUM(payment_value), 2) FROM clean_order_payments),
       (SELECT ROUND(SUM(payment_amount), 2) FROM mart_orders)
UNION ALL
SELECT '상품매출',
       (SELECT ROUND(SUM(price), 2) FROM clean_order_items),
       (SELECT ROUND(SUM(product_amount), 2) FROM mart_orders);

-- 그레인 중복 점검. 두 값 모두 0 이어야 한다.
SELECT
    (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM mart_orders)  AS dup_orders,
    (SELECT COUNT(*) FROM (
        SELECT order_id, order_item_id FROM mart_order_items
        GROUP BY order_id, order_item_id HAVING COUNT(*) > 1
    ) d)                                                            AS dup_items;

-- 커버리지 (NULL 이 얼마나 되는지 파악)
SELECT
    SUM(payment_amount IS NULL)  AS orders_without_payment,
    SUM(review_score IS NULL)    AS orders_without_review,
    SUM(customer_lat IS NULL)    AS orders_without_geo,
    SUM(item_count = 0)          AS orders_without_item
FROM mart_orders;
