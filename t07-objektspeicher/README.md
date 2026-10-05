# T07 – Object Storage mit Cloud Storage

**Ziel:** Ein privater Bucket für Rohdaten und Kartenkacheln, zeitlich begrenzter Zugriff über Signed URLs, Range Requests (Grundlage von PMTiles), CORS für den Abruf aus dem Browser und eine Lebenszyklusregel.

**Kosten:** Bei wenigen hundert Megabyte praktisch null (Speicher ca. 0,02–0,03 USD je GB und Monat; das Freikontingent von 5 GB gilt nur in US-Regionen).

## Schritte

```bash
./create-bucket.sh                 # Bucket, CORS, Lebenszyklus, Service Account, cities15000 nach raw/
./sign-url.sh                      # Signed URL, Test mit und ohne Signatur, Range Request
./upload.sh erfurt.pmtiles       # eigene Datei nach tiles/
./sign-url.sh tiles/erfurt.pmtiles
```

Eine PMTiles-Datei für eine Region lässt sich mit dem `pmtiles`-Werkzeug aus dem Dev Container aus dem täglichen Protomaps-Build schneiden, ohne den ganzen Planeten zu laden:

```bash
pmtiles extract https://build.protomaps.com/<YYYYMMDD>.pmtiles erfurt.pmtiles \
  --bbox=10.90,50.90,11.20,51.10 --maxzoom=14
```

Das aktuelle Datum steht unter <https://maps.protomaps.com/builds>.

## Was die Skripte einstellen

- Bucket mit **Uniform Bucket-Level Access** (Rechte nur über IAM, keine ACLs je Objekt) und erzwungener **Public Access Prevention**. Daten im Ruhezustand sind immer verschlüsselt.
- `cors.json`: GET und HEAD von jeder Herkunft, Header `Range` und `ETag` – nötig für MapLibre GL JS mit PMTiles.
- `lifecycle.json`: Objekte unter `raw/` werden nach 30 Tagen gelöscht, unvollständige Multipart-Uploads nach einem Tag.
- Signed URLs brauchen einen privaten Schlüssel. Statt eine Schlüsseldatei herunterzuladen, signiert Google im Auftrag des Service Accounts `pf-<owner>-signer` (Impersonation); dafür erhält das eigene Konto die Rolle *Service Account Token Creator* für genau diesen Service Account. Neue Rechte wirken nach etwa einer Minute.

## Prüfen

Die Ausgabe von `sign-url.sh` zeigt:

- ohne Signatur: `403` – der Bucket ist privat,
- mit Signatur und `Range: bytes=0-99`: `206 Partial Content` mit `Content-Range`.

## Aufräumen

```bash
./destroy-bucket.sh
```

## Cache (Theorie)

Ein verwalteter Cache (Memorystore for Valkey) kostet auch im kleinsten Ausbau jede Stunde Geld. Die Übung zum Caching läuft daher lokal mit Valkey im Dev Container.

## Anbieterwechsel

Nach Termin 7 wechselt jeder Teilnehmer den Anbieter. Wer neu zu Google Cloud kommt, arbeitet [t01-grundlagen](../t01-grundlagen/README.md) durch und liest die Zwischenpräsentation des Vorgängers. Wer Google Cloud verlässt, prüft mit `../tools/find-leftovers.sh`, dass nichts mehr läuft, oder löscht das ganze Projekt.

## Fragen zum Weiterdenken

- Warum ist eine Signed URL sicherer als ein öffentlicher Bucket, und wann ist sie trotzdem riskant?
- Welche Speicherklasse (Standard, Nearline, Coldline, Archive) passt zu selten gelesenen Rohdaten, und was kostet dann der Abruf?
- Wie würde Cloud CDN vor dem Bucket die Kosten für viele Kartenaufrufe senken?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Object Storage | S3 | Blob Storage | Cloud Storage |
| Zeitlich begrenzter Zugriff | Pre-Signed URL | SAS-Token | Signed URL |
| Cache | ElastiCache | Azure Managed Redis | Memorystore |
