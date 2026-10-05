# /// script
# requires-python = ">=3.12"
# dependencies = ["duckdb>=1.4"]
# ///
"""Query GeoParquet in Cloud Storage with DuckDB.

DuckDB uses the S3-compatible XML API of Cloud Storage with an HMAC key
(environment variables GCS_HMAC_ID and GCS_HMAC_SECRET, see
query-duckdb.sh). Overture Maps is queried with BigQuery (bigquery.sh),
because Overture does not publish its files on Cloud Storage.

Usage: uv run query_duckdb.py <bucket>
"""

import os
import sys

import duckdb


def show(con: duckdb.DuckDBPyConnection, title: str, sql: str) -> None:
    print(f"\n--- {title}")
    con.sql(sql).show(max_rows=20)


def main(bucket: str) -> None:
    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs;")
    key_id = os.environ["GCS_HMAC_ID"].replace("'", "''")
    secret = os.environ["GCS_HMAC_SECRET"].replace("'", "''")
    con.execute(f"CREATE SECRET lake (TYPE gcs, KEY_ID '{key_id}', SECRET '{secret}')")
    places = f"read_parquet('gs://{bucket}/places/*.parquet')"

    show(con, "Largest places in Germany", f"""
        SELECT name, population, round(latitude, 2) AS lat, round(longitude, 2) AS lon
        FROM {places} WHERE country_code = 'DE'
        ORDER BY population DESC LIMIT 10
    """)
    show(con, "Places with at least 15,000 inhabitants per country", f"""
        SELECT country_code, count(*) AS places, sum(population) AS population
        FROM {places} GROUP BY ALL ORDER BY places DESC LIMIT 10
    """)

    # H3: hexagonal grid cells (community extension)
    con.execute("INSTALL h3 FROM community; LOAD h3;")
    show(con, "Places per H3 cell (resolution 3) in Germany", f"""
        SELECT h3_h3_to_string(h3_latlng_to_cell(latitude, longitude, 3)) AS cell,
               count(*) AS places, string_agg(name, ', ') AS names
        FROM {places} WHERE country_code = 'DE'
        GROUP BY cell ORDER BY places DESC LIMIT 5
    """)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
