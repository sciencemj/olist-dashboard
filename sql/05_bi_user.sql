-- =====================================================================
-- 05. BI 도구용 읽기 전용 계정
--   Superset 은 Docker 컨테이너에서 host.docker.internal 로 붙기 때문에
--   'localhost' 가 아닌 호스트에서의 접속을 허용해야 한다.
--
--   노출 범위는 mart_* 두 개로 제한한다. raw_* / clean_* 은 주지 않는다.
--   sql/04_mart_tables.sql 이 먼저 실행돼 있어야 GRANT 가 붙는다.
--
--   비밀번호는 로컬 테스트용 고정값이다. 원격에서 실행할 일이 생기면 바꿔야한다.
--
--   실행: mysql -u root -p < sql/05_bi_user.sql
--   Superset 연결 URI:
--     mysql+pymysql://superset:superset@host.docker.internal:3306/olist
-- =====================================================================

CREATE USER IF NOT EXISTS 'superset'@'%' IDENTIFIED BY 'superset';

GRANT SELECT ON olist.mart_orders      TO 'superset'@'%';
GRANT SELECT ON olist.mart_order_items TO 'superset'@'%';

FLUSH PRIVILEGES;

-- 확인
SHOW GRANTS FOR 'superset'@'%';
