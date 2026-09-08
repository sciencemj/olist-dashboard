-- =====================================================================
-- 03. clean_* 외래키 설정
--   sql/02_clean_tables.sql 실행 직후에 돌린다.
--
--   clean_geolocation 은 FK 대상에서 제외한다. zip prefix 커버리지가
--   불완전해서(customers 278행, sellers 7행이 매칭 없음) FK 를 걸면
--   ALTER 가 실패한다. 좌표 참조용 lookup 테이블로만 둔다.
--
-- 실행: mysql -u <user> -p olist < sql/03_add_foreign_keys.sql
-- =====================================================================

USE olist;


-- ---------------------------------------------------------------------
-- 0. 사전 점검
-- ---------------------------------------------------------------------

-- 엔진이 InnoDB 여야 FK 가 걸린다. 전부 InnoDB 로 나와야 정상.
SELECT table_name, engine
FROM information_schema.tables
WHERE table_schema = 'olist' AND table_name LIKE 'clean_%'
ORDER BY table_name;

-- 고아 행 점검. 아래 6개 전부 0 이어야 다음 단계가 성공한다.
SELECT 'orders -> customers' AS relation, COUNT(*) AS orphans
FROM clean_orders o LEFT JOIN clean_customers c ON o.customer_id = c.customer_id
WHERE o.customer_id IS NOT NULL AND c.customer_id IS NULL
UNION ALL
SELECT 'order_items -> orders', COUNT(*)
FROM clean_order_items i LEFT JOIN clean_orders o ON i.order_id = o.order_id
WHERE i.order_id IS NOT NULL AND o.order_id IS NULL
UNION ALL
SELECT 'order_items -> products', COUNT(*)
FROM clean_order_items i LEFT JOIN clean_products p ON i.product_id = p.product_id
WHERE i.product_id IS NOT NULL AND p.product_id IS NULL
UNION ALL
SELECT 'order_items -> sellers', COUNT(*)
FROM clean_order_items i LEFT JOIN clean_sellers s ON i.seller_id = s.seller_id
WHERE i.seller_id IS NOT NULL AND s.seller_id IS NULL
UNION ALL
SELECT 'payments -> orders', COUNT(*)
FROM clean_order_payments p LEFT JOIN clean_orders o ON p.order_id = o.order_id
WHERE p.order_id IS NOT NULL AND o.order_id IS NULL
UNION ALL
SELECT 'reviews -> orders', COUNT(*)
FROM clean_order_reviews r LEFT JOIN clean_orders o ON r.order_id = o.order_id
WHERE r.order_id IS NOT NULL AND o.order_id IS NULL;


-- ---------------------------------------------------------------------
-- 1. 타입 정렬
--   FK 는 부모/자식 컬럼의 타입과 콜레이션이 정확히 같아야 한다 (errno 3780).
--   CTAS 로 만들어진 자식 컬럼을 부모 PK 와 동일한 VARCHAR(50) 으로 맞춘다.
--   NULL 허용은 유지한다 (FK 는 NULL 값을 검사하지 않는다).
-- ---------------------------------------------------------------------
ALTER TABLE clean_order_items
    MODIFY product_id VARCHAR(50) NULL,
    MODIFY seller_id  VARCHAR(50) NULL;

ALTER TABLE clean_order_reviews
    MODIFY order_id VARCHAR(50) NULL;


-- ---------------------------------------------------------------------
-- 2. 외래키
--   ON DELETE RESTRICT: 자식이 남아 있으면 부모 삭제를 막는다.
--   ON UPDATE CASCADE : 부모 키가 바뀌면 자식도 따라간다.
-- ---------------------------------------------------------------------

ALTER TABLE clean_orders
    ADD CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES clean_customers (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE clean_order_items
    ADD CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES clean_orders (order_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES clean_products (product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id) REFERENCES clean_sellers (seller_id)
        ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE clean_order_payments
    ADD CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES clean_orders (order_id)
        ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE clean_order_reviews
    ADD CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES clean_orders (order_id)
        ON DELETE RESTRICT ON UPDATE CASCADE;


-- ---------------------------------------------------------------------
-- 3. 검증
--   6행이 나와야 한다. 이제 DBeaver ER Diagram 에 관계선이 그려진다.
-- ---------------------------------------------------------------------
SELECT
    rc.constraint_name,
    rc.table_name          AS child_table,
    kcu.column_name        AS child_column,
    rc.referenced_table_name AS parent_table,
    kcu.referenced_column_name AS parent_column,
    rc.delete_rule,
    rc.update_rule
FROM information_schema.referential_constraints rc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_schema = rc.constraint_schema
 AND kcu.constraint_name   = rc.constraint_name
WHERE rc.constraint_schema = 'olist'
ORDER BY rc.table_name, rc.constraint_name;


-- =====================================================================
-- 참고: 02 를 다시 돌리려면
--
--   FK 가 걸린 상태에서는 02 의 DROP TABLE 이 실패한다. 둘 중 하나로 푼다.
--
--   (a) 검사를 잠시 끄고 02 를 재실행한 뒤 03 을 다시 돌린다.
--         SET FOREIGN_KEY_CHECKS = 0;
--         source sql/02_clean_tables.sql
--         SET FOREIGN_KEY_CHECKS = 1;
--         source sql/03_add_foreign_keys.sql
--
--   (b) FK 를 먼저 떨어뜨린다. 03 을 재실행하기 전에도 이 블록이 필요하다
--       (MySQL 에는 ADD CONSTRAINT IF NOT EXISTS 가 없다).
--         ALTER TABLE clean_orders        DROP FOREIGN KEY fk_orders_customer;
--         ALTER TABLE clean_order_items   DROP FOREIGN KEY fk_items_order;
--         ALTER TABLE clean_order_items   DROP FOREIGN KEY fk_items_product;
--         ALTER TABLE clean_order_items   DROP FOREIGN KEY fk_items_seller;
--         ALTER TABLE clean_order_payments DROP FOREIGN KEY fk_payments_order;
--         ALTER TABLE clean_order_reviews  DROP FOREIGN KEY fk_reviews_order;
-- =====================================================================
