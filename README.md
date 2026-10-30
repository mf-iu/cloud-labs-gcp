# Cloud-Übungen: Google Cloud

Skripte für den praktischen Teil des Kurses „Cloud Computing – Konzepte und Praxis für die Softwareentwicklung“ bei Google Cloud. Die Ordner enthalten nur, was beim Anbieter läuft; alles, was ohne Cloud-Konto geht, steht in [cloud-labs-local](https://github.com/mf-iu/cloud-labs-local). Die Gegenstücke für die anderen Anbieter liegen in `cloud-labs-aws` und `cloud-labs-azure`; Aufbau und Ordnernamen sind dort gleich.

Jeder Teilnehmer arbeitet in der ersten Kurshälfte (Termine 1–7) mit einem Anbieter und wechselt nach der Zwischenpräsentation zu einem anderen (Termine 8–12). Wer Google Cloud erst ab Termin 8 nutzt, richtet Konto und Projekt mit `01-account` ein und arbeitet dann mit `06-infrastructure-as-code` weiter.

## Voraussetzungen

- [cloud-labs-local](https://github.com/mf-iu/cloud-labs-local) und der eigene Fork von PlaceFinder **neben diesem Repository** in `~/kurs`, eingerichtet nach [cloud-labs-local/00-setup](https://github.com/mf-iu/cloud-labs-local/tree/master/00-setup). Die Skripte hier laden die gemeinsame Bibliothek von dort (`lib/common.sh`), der Dev Container baut dessen Dockerfile.
- Ein Google-Cloud-Konto mit Testguthaben – Einrichtung in [01-account](01-account/README.md)

## Arbeitsumgebung: Dev Container

`code ~/kurs/cloud-labs-gcp` öffnen und „Reopen in Container“ wählen. Der Dev Container baut das Dockerfile aus `cloud-labs-local/.devcontainer/` mit allen Werkzeugen der Übungen und ergänzt die CLI von Google Cloud; die Anmeldung liegt in WSL und übersteht einen Neubau. Unter `/workspaces` sind alle Repositories da: dieses, `cloud-labs-local` und `placefinder`. Beim Anlegen zeigen `../cloud-labs-local/tools/check-tools.sh` und `01-account/check-cli.sh --tools-only` die Versionen. Einzelheiten – Terminal, Ports, Neubau – stehen in [cloud-labs-local/00-setup](https://github.com/mf-iu/cloud-labs-local/tree/master/00-setup).

## Einrichtung

Im Terminal des Dev Containers, nachdem `config.env` in `cloud-labs-local` ausgefüllt ist:

```bash
cp config.example.env config.env      # Kürzel, Region, Budget usw. eintragen
01-account/check-cli.sh               # prüft CLI, Nachbarordner, Anmeldung und Einstellungen
```

`config.env` und der Ordner `.state/` gehören nur auf den eigenen Rechner und sind in `.gitignore` eingetragen. In `.state/` merken sich die Skripte die IDs der angelegten Ressourcen, damit die Aufräumskripte sie wiederfinden, außerdem Zugangsdaten der Übungsdatenbank. Downloads wie GeoNames und die Kacheln liegen in `cloud-labs-local/.state/data/`.

## Übersicht

Die Ordner folgen dem Inhalt; die Spalte *Termin* nennt, wann sie dran sind. Die lokalen Schritte desselben Termins stehen in der Übersicht von `cloud-labs-local`.

| Termin | Ordner | Inhalt | Werkzeug |
|---|---|---|---|
| 1 | [01-account](01-account/README.md) | Konto absichern, Projekt, CLI-Anmeldung, Budget-Alarm; Anbieterwechsel | gcloud |
| 2 | [02-vm](02-vm/README.md) | PlaceFinder v0 per cloud-init auf einer Compute-Engine-VM (IaaS) | gcloud |
| 3, 5 | [03-container-service](03-container-service/README.md) | Image in der Artifact Registry, Betrieb mit Cloud Run (Serverless Container); neue Version per Digest als Revision, Smoke-Test; Zusatz API Gateway mit API-Key und Kontingent | gcloud, curl |
| 4 | [04-network](04-network/README.md) | VPC mit Subnetzen, Firewall-Regeln mit Netzwerk-Tags; Zusatz Test-VMs mit Bastion-Host und Cloud NAT | gcloud |
| 6 (Zusatz), 7 | [05-storage](05-storage/README.md) | Cloud Storage mit Signed URLs, Range Requests, CORS und Kartenkacheln; Zusatz Cloud SQL for PostgreSQL mit PostGIS | gcloud, psql |
| 8 | [06-infrastructure-as-code](06-infrastructure-as-code/README.md) | `base` (VPC, Bucket, Artifact Registry, Dienstkonto) und `service` (Cloud Run, Cloud SQL mit privater Adresse) als Code, Remote State in Cloud Storage; Ausrollen aus GitHub Actions ohne Schlüssel (Workload Identity Federation) | OpenTofu, GitHub Actions |
| 9 | [t09-serverless](t09-serverless/README.md) | Täglicher GeoNames-Abgleich als Cloud Run function mit Cloud Scheduler | OpenTofu, Python |
| 10 | [t10-datenanalyse](t10-datenanalyse/README.md) | GeoParquet im Data Lake, Abfragen mit DuckDB und BigQuery, Overture Maps | OpenTofu, DuckDB, bq |
| 11 | [t11-ml](t11-ml/README.md) | Modell-Endpunkt `/estimate`, MLflow-Artefakte in Cloud Storage | OpenTofu |

Termin 12 (Abschluss) hat keinen eigenen Ordner; das Abschlussprojekt baut auf `06-infrastructure-as-code/base` auf. Die Ordner `t09` bis `t11` werden noch nach diesem Schema geordnet.

## Ablauf jeder Übung

1. Ressourcen anlegen: `create-….sh`, `deploy.sh` bzw. `tools/tofu.sh <ordner> apply`
2. Ausprobieren: Testbefehle aus der Anleitung des Termins
3. **Aufräumen:** `destroy-….sh` bzw. `tools/tofu.sh <ordner> destroy`
4. Kontrolle: `tools/find-leftovers.sh` listet übrig gebliebene Ressourcen auf

Alle Übungen laufen in **einem Projekt** pro Teilnehmer. Ressourcen heißen `<prefix>-<owner>-…`, z. B. `pf-mf-t02-vm`, und tragen die Labels `course=cloud-computing` und `lab=<termin>`, soweit der Dienst Labels kennt. Die Skripte schalten die benötigten APIs selbst ein. Sie fragen vor dem Löschen nach; mit `ASSUME_YES=1` vor dem Befehl entfällt die Rückfrage. Wer am Kursende alles auf einmal loswerden will, löscht das ganze Projekt: `gcloud projects delete <projekt-id>`.

**Ab Termin 8 mit OpenTofu:** `06-infrastructure-as-code/bootstrap-state.sh` legt einmalig den Bucket für den Remote State an. Danach läuft jede Konfiguration über `tools/tofu.sh`, das den Backend-Zugang und die gemeinsamen Variablen aus `config.env` setzt. OpenTofu meldet sich mit den Application Default Credentials an (`gcloud auth application-default login`).

```bash
tools/tofu.sh 06-infrastructure-as-code/base apply       # once, stays until the end of the course
tools/tofu.sh 06-infrastructure-as-code/service apply    # in the session
tools/tofu.sh 06-infrastructure-as-code/service destroy  # at the end of the session
```

## Regionen

Die meisten Übungen laufen in Frankfurt (`europe-west3`). Die dauerhaft kostenlose VM (`e2-micro`) gibt es nur in `us-west1`, `us-central1` und `us-east1`; deshalb legt `02-vm` die VM in `GCP_FREE_ZONE` an. Die Kartendaten sind öffentlich, der Speicherort in den USA ist für die Übung unkritisch.

## Kostenregeln

- Gleich am ersten Tag den Budget-Alarm einrichten (`01-account/create-budget.sh`).
- Nach jeder Übung alles abbauen; nur `06-infrastructure-as-code/base` bleibt bis zum Kursende. Teuer im Dauerbetrieb sind vor allem Cloud SQL, Cloud NAT, Load Balancer, reservierte IP-Adressen und GKE-Cluster.
- Das Testguthaben gilt 90 Tage. Nicht auf ein kostenpflichtiges Konto umstellen; danach wird das Konto geschlossen, aber nichts berechnet.
- Preisangaben in den Anleitungen sind Richtwerte (Stand Oktober 2026) und dienen nur der Orientierung.

## Daten und Lizenzen

- GeoNames (`cities15000`, tägliche Änderungsdateien): CC BY 4.0, Namensnennung „GeoNames“
- OpenStreetMap und Overture Maps: ODbL bzw. CDLA Permissive 2.0, je nach Thema
- Geodaten werden nie eingecheckt, sondern von den Skripten geladen.

## Konventionen

Anleitungen auf Deutsch, Skripte, Kommentare und Commit-Messages auf Englisch. Die Shell-Skripte sind mit ShellCheck geprüft (`shellcheck */*.sh`; `cloud-labs-local` muss daneben liegen), die OpenTofu-Dateien mit `tofu fmt`, die Python-Dateien mit Ruff (`ruff check`, `ruff format`).
