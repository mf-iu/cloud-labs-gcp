# T09 – Täglicher GeoNames-Abgleich als Function

**Ziel:** Eine Cloud Run function lädt jeden Morgen die Änderungs- und Löschdateien des Vortags von GeoNames, filtert sie auf die Orte von `cities15000` und legt sie in Cloud Storage ab. Ist `database_url` gesetzt, spielt sie die Änderungen zusätzlich in die Tabelle `places` ein. Gestartet wird sie von Cloud Scheduler.

**Kosten:** Im Freikontingent (Cloud Run: 2 Millionen Anfragen pro Monat; Cloud Scheduler: drei Jobs pro Rechnungskonto kostenlos). Beim Ausrollen baut Cloud Build das Container-Image; die ersten 2.500 Build-Minuten pro Monat sind kostenlos.

## Aufbau

| Datei | Inhalt |
|---|---|
| `function/geonames_sync.py` | anbieterneutraler Kern: Download, Filter, Speichern, optional Datenbank (identisch in allen drei Repositories) |
| `function/main.py` | HTTP-Function (Functions Framework): schreibt mit der Cloud-Storage-Bibliothek in den Bucket |
| `function/requirements.txt` | Abhängigkeiten; Cloud Build installiert sie beim Ausrollen |
| `infra/main.tf` | Bucket, Quellcode-Archiv, Service Accounts, Function, Zeitplan |
| `invoke.sh` | Function mit eigenem Identitätstoken aufrufen und Ergebnis anzeigen |

Cloud Run functions (früher Cloud Functions 2nd gen) sind Cloud-Run-Dienste, die Google aus dem Quellcode baut. OpenTofu packt `function/` als ZIP-Datei, legt sie im Bucket ab, und Cloud Build erzeugt daraus das Image.

## Lokal testen

```bash
cd function
python3 geonames_sync.py --date 2026-10-01 --out ../out
```

Ohne Cloud: Die Dateien landen unter `out/geonames/changes/<datum>/`. Die HTTP-Function lässt sich mit dem Functions Framework lokal starten (`uvx functions-framework --target sync`), braucht dann aber Zugriff auf einen Bucket (`DATA_BUCKET`).

## Ausrollen

```bash
cd ..
tools/tofu.sh t09-serverless/infra apply          # einige Minuten wegen Cloud Build
t09-serverless/invoke.sh                           # gestern
t09-serverless/invoke.sh 2026-10-01                # bestimmter Tag
gcloud storage ls --recursive "gs://$(tools/tofu.sh t09-serverless/infra output -raw bucket)/geonames"
```

Die Function ist privat: Aufrufen dürfen nur Konten mit der Rolle *Cloud Run Invoker*. `invoke.sh` schickt das eigene Identitätstoken mit (als Projektinhaber hat man die Rolle), Cloud Scheduler meldet sich mit einem OIDC-Token seines Service Accounts an. Der Zeitplan läuft täglich um 6:30 Uhr deutscher Zeit (`schedule`, Zeitzone `Europe/Berlin`).

Mit Datenbank (z. B. aus Termin 6; die Datenbank aus `t08-iac` liegt im privaten Netz und ist von außen nicht erreichbar):

```bash
tools/tofu.sh t09-serverless/infra apply -var "database_url=postgresql://…?sslmode=require"
```

Damit die Function die Datenbank erreicht, muss Cloud SQL Verbindungen von ihr annehmen. Cloud Run hat keine feste Absenderadresse; für die Übung genügt es, vorübergehend `0.0.0.0/0` als autorisiertes Netz einzutragen (das Passwort schützt weiterhin). Sauberer ist der Cloud SQL Connector für Python, der sich mit IAM anmeldet.

## Prüfen

- Ein zweiter Aufruf für denselben Tag ändert nichts (Idempotenz): gleiche Dateien, Upsert statt doppelter Zeilen.
- Logs: `gcloud functions logs read pf-<owner>-t09-geonames-sync --region europe-west3 --limit 20`
- Cloud Scheduler: In der Konsole unter *Cloud Scheduler* den Job mit *Force run* sofort starten.
- Kaltstart: Die erste Ausführung nach einer Pause dauert merklich länger.

## Aufräumen

```bash
tools/tofu.sh t09-serverless/infra destroy
```

## Optional: ereignisgesteuert

Eine zweite Function könnte auf neue Objekte im Bucket reagieren (Eventarc-Trigger `google.cloud.storage.object.v1.finalized`), etwa einen neuen OSM-Auszug unter `osm/` zu POIs verarbeiten. In OpenTofu: `event_trigger` in `google_cloudfunctions2_function`. Achtung bei Ereignissen auf demselben Bucket, in den die Function schreibt: Präfixe trennen, sonst entsteht eine Endlosschleife.

## Fragen zum Weiterdenken

- Was passiert, wenn GeoNames die Datei um 6:30 Uhr noch nicht veröffentlicht hat? Wie helfen die Wiederholungen von Cloud Scheduler (`retry_config`)?
- Warum muss die Function idempotent sein, obwohl sie nur einmal am Tag läuft?
- Ab wie vielen Aufrufen wäre ein dauerhaft laufender Container günstiger?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Function | Lambda | Azure Functions (Flex Consumption) | Cloud Run functions |
| Zeitsteuerung | EventBridge Scheduler | Timer-Trigger im Code | Cloud Scheduler |
| Lokale Entwicklung | SAM CLI | Functions Core Tools, Azurite | Functions Framework |
