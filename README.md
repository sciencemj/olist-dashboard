# olist-dashboard

Brazilian e-commerce (Olist) 데이터 분석.

## 구조

```
sql/         MySQL 적재 -> 정제 -> mart 파이프라인. 번호 순서대로 실행
notebooks/   DuckDB 로 CSV 를 바로 훑어보는 용도
docs/        ERD
data/        CSV 원본 (git 제외)
```

## 데이터

[Kaggle: Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
받아서 CSV 9개를 `data/` 에 넣는다. (용량 때문에 git 에는 포함하지 않음)

```bash
kaggle datasets download -d olistbr/brazilian-ecommerce -p data --unzip
```

## 실행 순서

MySQL 은 리포 루트에서 실행한다. 01 의 CSV 경로가 루트 기준 상대경로다.

```bash
mysql -u <user> -p --local-infile=1 < sql/01_raw_data.sql   # CSV -> raw_*
mysql -u <user> -p olist < sql/02_clean_tables.sql   # raw_* -> clean_*  (MySQL 8.0+)
mysql -u <user> -p olist < sql/03_add_foreign_keys.sql   # clean_* 외래키
mysql -u <user> -p olist < sql/04_mart_tables.sql        # clean_* -> mart_*  (BI 도구용)
mysql -u root -p < sql/05_bi_user.sql                    # BI 도구용 읽기 전용 계정
```

DuckDB:

```bash
uv sync
uv run jupyter lab notebooks/duckdb_data_preprocess.ipynb   # data/*.csv -> olist.duckdb
```
## 대시보드

Superset 을 Docker 로 띄우고 `mart_orders` / `mart_order_items` 두 개만 연결한다.
컨테이너에서 호스트 MySQL 로 나가므로 접속 주소는 `localhost` 가 아니라
`host.docker.internal` 이다.

```
mysql+pymysql://superset:superset@host.docker.internal:3306/olist
```

두 mart 를 BI 도구 안에서 다시 조인하지 않는다. 그레인이 달라 행이 부풀려진다.
스키마는 [docs/ERD.md](docs/ERD.md) 참고.
