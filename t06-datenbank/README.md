# T06 – Verwaltete PostgreSQL-Datenbank mit PostGIS

**Ziel:** Eine Cloud-SQL-Instanz mit PostgreSQL, die Erweiterungen PostGIS und pg_trgm, die Tabelle `places` mit GeoNames `cities15000` sowie räumliche und unscharfe Abfragen – einmal mit und einmal ohne Index.

**Kosten:** Edition Enterprise mit dem gemeinsam genutzten Kern `db-f1-micro` und 10 GB SSD ca. 0,015 USD pro Stunde aus dem Guthaben. **Nicht über Nacht laufen lassen.** Shared-Core-Maschinen sind nicht durch das SLA abgedeckt und nur für Tests gedacht.

## Schritte

```bash
./create-db.sh            # Instanz mit autorisiertem Netz = eigene IP, ca. 10 min
./load-cities.sh          # cities15000 laden, Tabelle und Indizes anlegen
./query.sh                # Beispielabfragen aus queries.sql
./query.sh --interactive  # interaktive psql-Sitzung
```

`create-db.sh` erzeugt ein zufälliges Passwort für den Benutzer `postgres` und speichert die Verbindungszeichenkette in `../.state/t06.env` (nicht eingecheckt). Die Instanz hat eine öffentliche IP-Adresse, akzeptiert aber nur Verbindungen aus dem autorisierten Netz, und die Verbindung ist mit TLS verschlüsselt (`sslmode=require`). Der Name enthält Datum und Uhrzeit, weil Google die Namen gelöschter Instanzen eine Woche lang sperrt.

Für Anwendungen ohne feste IP-Adresse gibt es den Cloud SQL Auth Proxy (bzw. die Connectors für Python), der sich mit IAM anmeldet; Cloud Run kann ihn direkt einbinden.

`load-cities.sh` lädt die Daten mit `\copy` (Bulk-Import über das COPY-Protokoll), ergänzt eine generierte Spalte `geom` vom Typ `geography(Point, 4326)`, die PostgreSQL aus Länge und Breite berechnet, und legt einen GiST-Index für räumliche Abfragen und einen GIN-Index mit Trigrammen für die unscharfe Namenssuche an.

### Lokale Datenbank und andere Dateien

Die Skripte nutzen `DATABASE_URL`, wenn die Variable gesetzt ist – zum Beispiel für eine lokale Datenbank mit PostGIS. Dafür in `compose.yaml` von PlaceFinder (aus Termin 2) einen Dienst `db` und ein Volume `pgdata` ergänzen. Den Übungsdienst `web` aus Termin 2 braucht PlaceFinder nicht; er kann bleiben oder entfallen.

```yaml
services:
  # api (and web) as before
  db:
    image: postgis/postgis:18-3.6        # PostgreSQL 18 with PostGIS 3.6 (amd64 only)
    environment:
      POSTGRES_USER: pf
      POSTGRES_PASSWORD: pf              # plain text for local development only
      POSTGRES_DB: pf
    ports: ["127.0.0.1:5432:5432"]       # reachable from this computer only
    # from PostgreSQL 18 on, the volume belongs at /var/lib/postgresql
    volumes: [pgdata:/var/lib/postgresql]
    healthcheck:
      # --host 127.0.0.1: check via TCP, the init server only listens on the socket
      test: pg_isready --host 127.0.0.1 --username pf
      interval: 5s

volumes:
  www:
  pgdata:
```

```bash
(cd /workspaces/placefinder && docker compose up --detach db)   # db: healthy in docker compose ps
export DATABASE_URL=postgresql://pf:pf@localhost:5432/pf
export PGOPTIONS="--jit=off --max_parallel_workers_per_gather=0"   # einfache Pläne
./load-cities.sh
./query.sh
```

Andere GeoNames-Dateien lädt `./load-cities.sh <name>`; das Skript holt die Datei von GeoNames und ersetzt die Tabelle `places`. Statt eines Namens geht auch der Pfad einer vorhandenen Datei.

```bash
./load-cities.sh DE             # Länderdatei Deutschland, auch Berge, Seen, Ortsteile
./load-cities.sh allCountries   # rund 13 Millionen Einträge, Download ca. 400 MB
```

## Prüfen

`queries.sql` enthält:

1. die zehn nächsten Orte zu Erfurt (KNN-Suche mit `<->`),
2. eine Suche über `asciiname` ohne und mit B-Baum-Index (der Index wird mit `ROLLBACK` wieder entfernt),
3. alle Orte im Umkreis von 50 km mit `EXPLAIN ANALYZE` (Bitmap Index Scan),
4. dieselbe Umkreisabfrage mit abgeschaltetem Index (Seq Scan) zum Vergleich,
5. eine unscharfe Suche „Wuerzburg“ → „Würzburg“.

In der Konsole unter *SQL* → Instanz: *Overview* (Metriken), *Backups* (automatische Backups, Wiederherstellung auf einen Zeitpunkt), *Query insights*.

## Zusatz: POIs aus OpenStreetMap

`load-pois.sh` lädt einen Auszug von Geofabrik (Standard: Thüringen, ca. 150 MB) und importiert mit osm2pgsql (getestet mit 1.11 aus `sudo apt install osm2pgsql` unter Ubuntu 24.04 und mit 2.3) alle benannten Punkte mit `amenity`- oder `tourism`-Tag in die Tabelle `pois` (`pois.lua`) – in Thüringen rund 24.000. POIs, die als Fläche erfasst sind, fehlen. osm2pgsql schreibt `geometry`; `pois.sql` ergänzt deshalb eine Spalte `geog` vom Typ `geography` mit GiST-Index, damit Abstände in Metern gerechnet werden.

```bash
./load-pois.sh                                     # Thüringen
./load-pois.sh europe/germany/sachsen              # anderer Auszug
```

Für spätere Updates mit `osm2pgsql-replication` muss der Import mit `--slim` laufen. Daten © OpenStreetMap contributors, ODbL.

## Aufräumen

```bash
./destroy-db.sh
```

## Fragen zum Weiterdenken

- Welche Aufgaben übernimmt Cloud SQL gegenüber PostgreSQL auf einer eigenen VM?
- Was ändert sich mit der Edition Enterprise Plus (SLA, Wartungsfenster, Data Cache)?
- Warum ist die Abfrage mit Index schneller, obwohl beide dieselbe Funktion `ST_DWithin` verwenden?
- Wie müsste die Instanz ins Netz aus Termin 4 (private IP über Private Service Access), damit nur die Anwendung sie erreicht?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Dienst | RDS for PostgreSQL | Azure Database for PostgreSQL (Flexible Server) | Cloud SQL for PostgreSQL |
| Kleinste Größe | `db.t4g.micro` | `Standard_B1ms` | `db-f1-micro` |
| PostGIS aktivieren | `CREATE EXTENSION` | erst freigeben (`azure.extensions`), dann `CREATE EXTENSION` | `CREATE EXTENSION` |
