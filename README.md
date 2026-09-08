# olist-dashboard

Brazilian e-commerce (Olist) 데이터 분석.

## 데이터

[Kaggle: Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
받아서 CSV 9개를 `data/` 에 넣는다. (용량 때문에 git 에는 포함하지 않음)

```bash
kaggle datasets download -d olistbr/brazilian-ecommerce -p data --unzip
```

## 실행 순서

MySQL:

```bash
mysql -u <user> -p < 01_raw_data.sql   # CSV -> raw_*  (LOCAL INFILE 허용 필요)
mysql -u <user> -p olist < 02_claen_table.sql   # raw_* -> clean_*  (MySQL 8.0+)
```

DuckDB:

```bash
uv sync
uv run jupyter lab data_preprocess.ipynb   # data/*.csv -> olist.duckdb
```
