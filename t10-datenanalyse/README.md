# T10 – Data Lake mit GeoParquet, DuckDB und BigQuery

**Ziel:** GeoNames-Orte liegen als GeoParquet in Cloud Storage. DuckDB fragt die Datei direkt im Bucket ab. BigQuery führt Abfragen serverlos über eine externe Tabelle aus (Schema on Read) und liest die Overture-Maps-Daten aus den öffentlichen Datensätzen.

**Kosten:** Speicher praktisch null. BigQuery: 1 TiB Abfragen pro Monat kostenlos, danach ca. 6 USD je TiB. `bigquery.sh` begrenzt jede Abfrage auf 20 GB abgerechnete Daten.

## Schritte

```bash
cd ..
tools/tofu.sh t10-datenanalyse/infra apply   # Bucket, Service Account mit HMAC-Schlüssel, BigQuery-Dataset und -Tabelle
t10-datenanalyse/upload.sh                    # cities15000 -> GeoParquet -> gs://…/places/
t10-datenanalyse/query-duckdb.sh              # DuckDB auf Cloud Storage
t10-datenanalyse/bigquery.sh                  # Beispielabfragen in BigQuery
t10-datenanalyse/bigquery.sh "SELECT name, population FROM \`<projekt>.<dataset>.places\` WHERE country_code = 'DE' ORDER BY population DESC LIMIT 5"
```

`export_geoparquet.py` schreibt eine Geometriespalte `geom` als WKB mit GeoParquet-Metadaten und behält Breite und Länge als normale Spalten, damit auch Werkzeuge ohne Geometrietyp damit arbeiten können. Die Datei ist nach Land sortiert, sodass Filter auf `country_code` ganze Row Groups überspringen.

DuckDB greift über die S3-kompatible XML-API auf Cloud Storage zu und braucht dafür einen **HMAC-Schlüssel**. OpenTofu legt ihn für den Service Account `pf-<owner>-t10-reader` an, der nur den Data-Lake-Bucket lesen darf. Der geheime Teil steht im State – ein weiterer Grund, den State gut zu schützen.

### Overture Maps

Overture Maps ist bei Google in den öffentlichen Datensätzen von BigQuery verfügbar (`bigquery-public-data.overture_maps`, Speicherort USA). `bigquery.sh` fragt Orte rund um Erfurt aus der Tabelle `place` ab. Abgerechnet werden nur die gelesenen Spalten; deshalb nie `SELECT *` auf diese Tabellen.

## Prüfen

- In der BigQuery-Konsole unter *Job history* steht für jede Abfrage die verarbeitete Datenmenge. Wie ändert sie sich, wenn nur zwei Spalten abgefragt werden?
- Vor dem Ausführen schätzt `bq query --dry_run` die Datenmenge.
- Die externe Tabelle `places` im Dataset ansehen: Schema, Quelle, keine gespeicherten Daten.

## Aufräumen

```bash
tools/tofu.sh t10-datenanalyse/infra destroy
```

## Fragen zum Weiterdenken

- Warum ist Parquet für Analysen schneller und billiger als CSV, obwohl die Daten dieselben sind?
- Wann reicht DuckDB auf einem Rechner, und wann braucht man BigQuery oder Spark (Dataproc)?
- Was bedeutet „Schema on Read“ für Fehler in den Daten? Was ändert sich, wenn die Daten in eine native BigQuery-Tabelle geladen werden?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Data Lake | S3 | Blob Storage / Data Lake Storage | Cloud Storage |
| Serverlose SQL-Abfragen | Athena | Fabric, Synapse serverless SQL | BigQuery |
| Overture Maps | S3 (us-west-2) | Blob Storage (West US 2) | BigQuery Public Datasets |
