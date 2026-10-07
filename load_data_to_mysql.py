"""
Olist E-Commerce Data Ingestion Script for MySQL (Fixed & Robust)
File: scripts/load_data_to_mysql.py
Description: Fast batch ETL script to load Olist CSV files into MySQL 8.0.
Properly handles numpy NaN / pandas NA / blank timestamps to SQL NULL.
"""

import os
import sys
import getpass
import argparse
import pandas as pd
import numpy as np
import pymysql

DATA_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))

def get_connection(host, user, password, port, database):
    return pymysql.connect(
        host=host,
        user=user,
        password=password,
        port=port,
        database=database,
        charset='utf8mb4',
        autocommit=False
    )

def bulk_insert(cursor, conn, table_name, columns, data_tuples, batch_size=5000):
    cols_str = ", ".join(f"`{c}`" for c in columns)
    placeholders = ", ".join(["%s"] * len(columns))
    sql = f"INSERT INTO `{table_name}` ({cols_str}) VALUES ({placeholders})"
    
    total = len(data_tuples)
    for i in range(0, total, batch_size):
        batch = data_tuples[i:i + batch_size]
        cursor.executemany(sql, batch)
        conn.commit()
    print(f"  [SUCCESS] {table_name}: loaded {total:,} rows.")

def to_clean_tuples(df):
    """
    Converts DataFrame to a list of tuples with clean Python types:
    - np.nan, pd.NA, NaT, and float('nan') become Python None (SQL NULL)
    """
    records = []
    for row in df.itertuples(index=False, name=None):
        clean_row = []
        for val in row:
            if pd.isna(val) or (isinstance(val, float) and np.isnan(val)) or str(val).lower() == 'nan':
                clean_row.append(None)
            else:
                clean_row.append(val)
        records.append(tuple(clean_row))
    return records

def main():
    parser = argparse.ArgumentParser(description="Load Olist CSVs into MySQL")
    parser.add_argument("--host", default="localhost", help="MySQL Host")
    parser.add_argument("--port", type=int, default=3306, help="MySQL Port")
    parser.add_argument("--user", default="root", help="MySQL User")
    parser.add_argument("--password", default=None, help="MySQL Root Password")
    parser.add_argument("--database", default="olist_ecommerce", help="Database name")
    args = parser.parse_args()

    password = args.password
    if password is None:
        password = getpass.getpass("Enter MySQL root password: ")

    print(f"\nConnecting to MySQL ({args.user}@{args.host}:{args.port}/{args.database})...")
    try:
        conn = get_connection(args.host, args.user, password, args.port, args.database)
        cursor = conn.cursor()
        print("Connected successfully!")
    except Exception as e:
        print(f"\n[ERROR] Connection failed: {e}")
        sys.exit(1)

    try:
        cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
        cursor.execute("SET UNIQUE_CHECKS = 0;")
        conn.commit()

        # 1. Product Category Name Translation
        print("\nLoading 1/9: product_category_translation...")
        df_cat = pd.read_csv(os.path.join(DATA_DIR, 'product_category_name_translation.csv'))
        cursor.execute("TRUNCATE TABLE product_category_translation;")
        bulk_insert(cursor, conn, 'product_category_translation', 
                    ['product_category_name', 'product_category_name_english'], 
                    to_clean_tuples(df_cat))

        # 2. Sellers
        print("Loading 2/9: sellers...")
        df_sellers = pd.read_csv(os.path.join(DATA_DIR, 'olist_sellers_dataset.csv'))
        cursor.execute("TRUNCATE TABLE sellers;")
        bulk_insert(cursor, conn, 'sellers', 
                    ['seller_id', 'seller_zip_code_prefix', 'seller_city', 'seller_state'], 
                    to_clean_tuples(df_sellers))

        # 3. Customers
        print("Loading 3/9: customers...")
        df_cust = pd.read_csv(os.path.join(DATA_DIR, 'olist_customers_dataset.csv'))
        cursor.execute("TRUNCATE TABLE customers;")
        bulk_insert(cursor, conn, 'customers', 
                    ['customer_id', 'customer_unique_id', 'customer_zip_code_prefix', 'customer_city', 'customer_state'], 
                    to_clean_tuples(df_cust))

        # 4. Products
        print("Loading 4/9: products...")
        df_prod = pd.read_csv(os.path.join(DATA_DIR, 'olist_products_dataset.csv'))
        # Column rename: 'lenght' -> 'length'
        df_prod = df_prod.rename(columns={
            'product_name_lenght': 'product_name_length',
            'product_description_lenght': 'product_description_length'
        })
        cursor.execute("TRUNCATE TABLE products;")
        bulk_insert(cursor, conn, 'products', list(df_prod.columns), to_clean_tuples(df_prod))

        # 5. Orders
        print("Loading 5/9: orders...")
        df_orders = pd.read_csv(os.path.join(DATA_DIR, 'olist_orders_dataset.csv'))
        cursor.execute("TRUNCATE TABLE orders;")
        bulk_insert(cursor, conn, 'orders', list(df_orders.columns), to_clean_tuples(df_orders))

        # 6. Order Items
        print("Loading 6/9: order_items...")
        df_items = pd.read_csv(os.path.join(DATA_DIR, 'olist_order_items_dataset.csv'))
        cursor.execute("TRUNCATE TABLE order_items;")
        bulk_insert(cursor, conn, 'order_items', list(df_items.columns), to_clean_tuples(df_items))

        # 7. Order Payments
        print("Loading 7/9: order_payments...")
        df_pay = pd.read_csv(os.path.join(DATA_DIR, 'olist_order_payments_dataset.csv'))
        cursor.execute("TRUNCATE TABLE order_payments;")
        bulk_insert(cursor, conn, 'order_payments', list(df_pay.columns), to_clean_tuples(df_pay))

        # 8. Order Reviews
        print("Loading 8/9: order_reviews...")
        df_rev = pd.read_csv(os.path.join(DATA_DIR, 'olist_order_reviews_dataset.csv'))
        df_rev = df_rev.drop_duplicates(subset=['review_id', 'order_id'])
        cursor.execute("TRUNCATE TABLE order_reviews;")
        bulk_insert(cursor, conn, 'order_reviews', list(df_rev.columns), to_clean_tuples(df_rev))

        # 9. Geolocation (Centroid aggregation: 1M rows -> 19K unique zip prefixes)
        print("Loading 9/9: geolocation (Optimized Centroid Per Zip Prefix)...")
        df_geo = pd.read_csv(os.path.join(DATA_DIR, 'olist_geolocation_dataset.csv'))
        df_geo_agg = df_geo.groupby('geolocation_zip_code_prefix').agg({
            'geolocation_lat': 'mean',
            'geolocation_lng': 'mean',
            'geolocation_city': 'first',
            'geolocation_state': 'first'
        }).reset_index()
        cursor.execute("TRUNCATE TABLE geolocation;")
        bulk_insert(cursor, conn, 'geolocation', list(df_geo_agg.columns), to_clean_tuples(df_geo_agg))

        # Re-enable foreign key constraints
        cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")
        cursor.execute("SET UNIQUE_CHECKS = 1;")
        conn.commit()

        print("\n" + "="*50)
        print("🎉 ALL 9 TABLES LOADED SUCCESSFULLY INTO MYSQL!")
        print("="*50 + "\n")

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR during loading]: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    main()
