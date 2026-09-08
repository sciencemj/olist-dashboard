# ERD

## 실제 스키마 (DBeaver)

![olist ERD](olist-ERD.png)

`clean_*` 사이의 연결선이 `03_add_foreign_keys.sql` 로 건 외래키 6개다.
`raw_*` 는 적재 전용이라 FK 가 없어 선 없이 떠 있고, `clean_geolocation` 도 마찬가지로
연결선이 없다 (아래 참고).

`mart_orders` / `mart_order_items` 는 BI 도구가 바라보는 층이다. 이미 조인이 끝난
결과라 서로 연결하지 않는다 (그레인이 달라 조인하면 행이 부풀려진다).

> DBeaver 는 메타데이터를 캐싱한다. FK 를 건 뒤에도 선이 안 보이면
> 좌측 트리에서 `olist` 우클릭 → Refresh (F5) 후 다이어그램 탭을 다시 연다.

## 논리 ERD (clean_*)

```mermaid
erDiagram
    clean_customers {
        varchar customer_id PK
        varchar customer_unique_id
        int     customer_zip_code_prefix FK
        varchar customer_city
        varchar customer_state
    }

    clean_orders {
        varchar  order_id PK
        varchar  customer_id FK
        varchar  order_status
        datetime order_purchase_timestamp
        datetime order_approved_at
        datetime order_delivered_carrier_date
        datetime order_delivered_customer_date
        datetime order_estimated_delivery_date
        int      delivery_days "파생"
        int      delivery_delay_days "파생"
    }

    clean_order_items {
        varchar  order_id PK,FK
        int      order_item_id PK
        varchar  product_id FK
        varchar  seller_id FK
        datetime shipping_limit_date
        decimal  price
        decimal  freight_value
        decimal  item_total "파생"
    }

    clean_order_payments {
        varchar order_id PK,FK
        int     payment_sequential PK
        varchar payment_type
        int     payment_installments
        decimal payment_value
    }

    clean_order_reviews {
        varchar  review_id PK
        varchar  order_id FK
        int      review_score
        text     review_comment_title
        text     review_comment_message
        datetime review_creation_date
        datetime review_answer_timestamp
    }

    clean_products {
        varchar product_id PK
        varchar product_category "영문"
        varchar product_category_pt
        int     product_name_length
        int     product_description_length
        int     product_photos_qty
        decimal product_weight_g
        decimal product_length_cm
        decimal product_height_cm
        decimal product_width_cm
        decimal product_volume_cm3 "파생"
    }

    clean_sellers {
        varchar seller_id PK
        int     seller_zip_code_prefix FK
        varchar seller_city
        varchar seller_state
    }

    clean_geolocation {
        int     zip_code_prefix PK
        decimal lat
        decimal lng
        varchar city
        varchar state
    }

    clean_customers    ||--o{ clean_orders          : "주문한다"
    clean_orders       ||--|{ clean_order_items     : "품목을 담는다"
    clean_orders       ||--o{ clean_order_payments  : "결제된다"
    clean_orders       ||--o| clean_order_reviews   : "리뷰가 달린다"
    clean_products     ||--o{ clean_order_items     : "판매된다"
    clean_sellers      ||--o{ clean_order_items     : "발송한다"
    clean_geolocation  ||--o{ clean_customers       : "위치"
    clean_geolocation  ||--o{ clean_sellers         : "위치"
```

FK 제약은 `03_add_foreign_keys.sql` 에서 6개를 건다.

`clean_geolocation` 만 예외로 FK 없이 둔다. zip prefix 커버리지가 불완전해서
(customers 278행, sellers 7행이 매칭 없음) FK 를 걸면 ALTER 가 실패한다.
좌표 참조용 lookup 테이블로만 쓰고, 조인은 zip prefix 로 직접 한다.
