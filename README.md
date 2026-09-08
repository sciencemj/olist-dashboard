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

MySQL:

```bash
mysql -u <user> -p < sql/01_raw_data.sql   # CSV -> raw_*  (LOCAL INFILE 허용 필요)
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
