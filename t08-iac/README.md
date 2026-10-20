# T08 – Infrastruktur als Code, Pipeline und Beobachtbarkeit

**Ziel:** Infrastruktur entsteht reproduzierbar aus Code. Zuerst lokal: OpenTofu startet PlaceFinder und Valkey als Container. Dann beim neuen Anbieter: Die Infrastruktur der Zwischenpräsentation – Netz aus Termin 4, Bucket aus Termin 7, Cloud-Run-Dienst aus Termin 3, auf Wunsch die Datenbank aus Termin 6 – entsteht aus OpenTofu-Code mit Remote State in Cloud Storage. Eine Pipeline in GitHub Actions testet, baut, scannt und signiert das Image von PlaceFinder; ein zweiter Workflow rollt es ohne JSON-Schlüssel aus. Traces und Metriken zeigt Grafana.

| Ordner oder Datei | Aufgabe |
|---|---|
| `local/` | OpenTofu mit dem Docker-Provider: Netz, Valkey und PlaceFinder als Container (Teil 1) |
| `bootstrap-state.sh`, `destroy-state.sh` | Bucket für den Remote State anlegen bzw. am Kursende löschen |
| `infra/` | Infrastruktur der Zwischenpräsentation: VPC, Bucket, Artifact Registry vor ghcr.io, PlaceFinder auf Cloud Run, optional Cloud SQL for PostgreSQL |
| `github-oidc/` | Vertrauensstellung für GitHub Actions: Workload Identity Pool und Dienstkonto, das nur der eigene Fork nutzen darf |
| `deploy.example.yml` | Workflow für den eigenen Fork: Image aus der Pipeline per Digest ausrollen, Smoke-Test |

Dazu gehört PlaceFinder ab Tag `t08`: die CI-Pipeline `.github/workflows/ci.yml`, Telemetrie mit OpenTelemetry und `DATABASE_INIT` (README von PlaceFinder, Abschnitte *Pipeline*, *Beobachtbarkeit* und *Datenbank selbst füllen*).

**Kosten:** Teil 1 läuft lokal und kostet nichts; GitHub Actions ist für öffentliche Repositories kostenlos. Teil 2: Cloud Run bleibt im Freikontingent, das zwischengespeicherte Image in Artifact Registry ebenfalls (0,5 GB). Cloud SQL `db-f1-micro` ca. 0,015 USD pro Stunde aus dem Guthaben. **Nach dem Test `destroy` ausführen.**

## Voraussetzungen

- Dev Container dieses Repositorys mit OpenTofu ab 1.10 (`tools/check-tools.sh`)
- Teil 2: Projekt beim neuen Anbieter eingerichtet (`t01-grundlagen`, Anbieterwechsel in [t07-objektspeicher](../t07-objektspeicher/README.md#anbieterwechsel)), `gcloud auth login` und `gcloud auth application-default login` aktiv – OpenTofu meldet sich mit den Application Default Credentials an –, `config.env` ausgefüllt
- Image `$PLACEFINDER_IMAGE:t08` öffentlich auf ghcr.io: `t03-container/build-image.sh --push --tag t08`, danach das Paket auf GitHub öffentlich machen

## Teil 1: lokal (Übung im Termin)

### OpenTofu mit Docker

`local/` beschreibt, was sonst `compose.yaml` erledigt: ein Netz, Valkey und PlaceFinder als Container. Der State bleibt als Datei im Ordner (`terraform.tfstate`, nicht eingecheckt).

```bash
cd /workspaces/placefinder && docker compose build api      # Image placefinder:0.8.0 aus dem eigenen Fork
cd /workspaces/cloud-labs-gcp/t08-iac/local
tofu init                                   # lädt den Docker-Provider, legt .terraform.lock.hcl an
tofu plan                                   # was würde passieren? 5 to add
tofu apply                                  # nach Rückfrage anlegen
tofu output                                 # http://localhost:8101
curl "http://localhost:8101/v1/places?q=Erfurt" --include | grep --ignore-case cache-status
```

`docker compose build api` baut das Image unter dem Namen aus `compose.yaml`, ab Tag `t08` `placefinder:0.8.0`. Mit anderem Namen oder ohne eigenes Image: `tofu apply -var placefinder_image=ghcr.io/<github-user>/placefinder:t08`.

**Ausprobieren:**

1. **Ändern:** `tofu apply -var instances=2` – der Plan zeigt *1 to add*: ein zweiter Container auf Port 8102, der Rest bleibt.
2. **Ersetzen:** `tofu apply -var instances=2 -var cache_ttl=60` – eine geänderte Umgebungsvariable lässt sich an einem laufenden Container nicht ändern; der Plan zeigt `-/+` (*must be replaced*).
3. **Drift:** `docker rm --force pf-t08-valkey`, dann `tofu plan` – OpenTofu vergleicht den State mit der Wirklichkeit und will Valkey neu anlegen. `tofu apply` stellt den beschriebenen Zustand wieder her.
4. **State ansehen:** `tofu state list`, `tofu state show 'docker_container.placefinder[0]'`
5. **Abbauen:** `tofu destroy` – Container und Netz verschwinden, die Images bleiben (`keep_locally`).

### Pipeline im eigenen Fork

Der Tag `t08` von PlaceFinder enthält die Pipeline. In den eigenen Fork übernehmen (`upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose)):

```bash
cd /workspaces/placefinder
git fetch upstream --tags                # Tag t08 der Musterlösung holen
git checkout t08 -- .github/workflows/ci.yml .github/dependabot.yml
uv run ruff format && uv run ruff check && uv run pytest      # vorher lokal grün?
git add .github && git commit --message "Add CI pipeline" && git push
```

Auf GitHub unter *Actions* den Lauf verfolgen. Auf `master` lädt der Job `image` das Image als `ghcr.io/<github-user>/placefinder:<commit>` und `:master` hoch, mit SBOM, Provenance und Signatur. Was die Schritte tun und wie sich die Signatur prüfen lässt: README von PlaceFinder, Abschnitt *Pipeline*.

### Beobachtbarkeit lokal

```bash
cd /workspaces/placefinder
OTEL_EXPORTER_OTLP_ENDPOINT=http://lgtm:4318 docker compose --profile observability up --detach --build
```

Last erzeugen, dann in Grafana (http://localhost:3000) das Dashboard *RED Metrics*, die Traces in Tempo und die Abfragen für die SLIs ansehen – Schritt für Schritt im README von PlaceFinder, Abschnitt *Beobachtbarkeit*.

## Teil 2: beim neuen Anbieter (Selbstlernphase)

### 1. Remote State einrichten (einmalig)

```bash
cd /workspaces/cloud-labs-gcp
t08-iac/bootstrap-state.sh
```

Das Skript legt einen versionierten, privaten Bucket `pf-<owner>-<suffix>-tfstate` an und schreibt `.state/backend.hcl`. Gesperrt wird der State über eine Lock-Datei im Bucket. Den Bucket legt die CLI an, weil OpenTofu seinen State-Speicher nicht verwalten kann, bevor es ihn gibt (Henne-Ei-Problem).

### 2. Infrastruktur ausrollen

```bash
tools/tofu.sh t08-iac/infra plan      # beim ersten Aufruf mit init
tools/tofu.sh t08-iac/infra apply     # ca. 5 Minuten, beim ersten Mal schalten APIs frei
tools/tofu.sh t08-iac/infra output
curl "$(tools/tofu.sh t08-iac/infra output -raw service_url)/health"
```

`tools/tofu.sh` setzt die Variablen `prefix`, `owner`, `suffix`, `project`, `region` und `placefinder_image` aus `config.env` und verwendet für jeden Ordner ein eigenes Präfix im State-Bucket, z. B. `t08-iac/infra/default.tfstate`.

| Datei | Inhalt |
|---|---|
| `infra/network.tf` | APIs, VPC mit Subnetzen `public` und `app` wie in Termin 4, Firewall-Regeln mit Netzwerk-Tags; mit Datenbank der reservierte Bereich `10.20.20.0/24` und das Peering zu Google |
| `infra/storage.tf` | privater Bucket mit CORS und Lebenszyklusregeln wie in Termin 7; Remote Repository in Artifact Registry vor ghcr.io |
| `infra/service.tf` | Dienstkonto und PlaceFinder auf Cloud Run mit Direct VPC Egress ins Subnetz `app` |
| `infra/database.tf` | optional: Cloud SQL for PostgreSQL 18 mit privater Adresse, Passwort in Secret Manager |
| `infra/outputs.tf` | URL und Name des Dienstes, Image-Repository, Bucket, Datenbank |

**Warum ein Remote Repository?** Cloud Run lädt Images nur aus Artifact Registry (und Docker Hub), nicht von ghcr.io. Ein Remote Repository steht als Zwischenspeicher davor: Cloud Run fragt dort, Artifact Registry holt das Image beim ersten Mal von ghcr.io. Niemand muss etwas hochladen.

### Mit Datenbank

```bash
tools/tofu.sh t08-iac/infra apply -var enable_database=true    # ca. 15 Minuten mehr
curl "$(tools/tofu.sh t08-iac/infra output -raw service_url)/health"   # "places": 34000 und mehr
```

Verwaltete Datenbanken laufen bei Google in einem eigenen Netz. *Private Services Access* reserviert dafür den Bereich `10.20.20.0/24` des VPC und verbindet beide Netze per Peering; Cloud SQL bekommt eine Adresse aus diesem Bereich und keine öffentliche. Cloud Run schickt Verkehr in private Bereiche über das Subnetz `app` (Direct VPC Egress) mit dem Netzwerk-Tag `app`; die Firewall erlaubt von dort nur PostgreSQL zur Datenbank. Vom eigenen Rechner aus ist sie nicht erreichbar, `load-cities.sh` geht also nicht. Stattdessen lädt PlaceFinder beim ersten Start die Orte aus dem Image (`DATABASE_INIT=true`).

Das Passwort erzeugt OpenTofu (`random_password`) und legt es in Secret Manager ab; nur das Dienstkonto von PlaceFinder darf es lesen. Cloud Run gibt es als `PGPASSWORD` an PlaceFinder, die Verbindungszeichenkette `DATABASE_URL` enthält kein Passwort. Im State steht es aber – ein Grund, warum der State privat und verschlüsselt liegt. Ganz ohne Passwort ginge es mit der IAM-Anmeldung von Cloud SQL.

### 3. Ausrollen aus der Pipeline, ohne Schlüssel

```bash
tools/tofu.sh t08-iac/github-oidc apply -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/github-oidc output
```

Die Konfiguration legt einen Workload Identity Pool mit einem Anbieter für GitHub Actions an. Die Bedingung lässt nur Tokens des genannten Repositorys und des Branches `master` zu. Damit darf der Workflow als Dienstkonto `pf-<owner>-github-deploy` handeln: Cloud-Run-Revisionen ausrollen (*Cloud Run Developer*) und dabei das Dienstkonto von PlaceFinder verwenden – sonst nichts. Ein gelöschter Pool bleibt 30 Tage reserviert; nach einem `destroy` mit `-var pool_id=<neuer-name>` arbeiten.

Im eigenen PlaceFinder-Fork:

1. `deploy.example.yml` als `.github/workflows/deploy.yml` übernehmen, committen, pushen.
2. Repository-Variablen anlegen (*Settings* → *Secrets and variables* → *Actions* → *Variables*): `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` und `GCP_REGION` aus `github-oidc`, `SERVICE_NAME`, `IMAGE_REPOSITORY` und `SERVICE_URL` (Ausgabe `service_url`) aus `infra`.
3. Eine kleine Änderung pushen. Nach der grünen Pipeline startet `deploy`: Image per Digest als neue Revision ausrollen (ca. eine Minute), dann der Smoke-Test aus Termin 5.

**Pipeline und OpenTofu:** `image_tag` bestimmt nur das erste Image. Danach rollt die Pipeline aus; `ignore_changes` in `service.tf` verhindert, dass das nächste `apply` auf `image_tag` zurücksetzt. Jede Eigenschaft gehört genau einem Werkzeug.

### 4. Logs und Metriken beim Anbieter

```bash
gcloud run services logs read pf-<owner>-t08-placefinder --region europe-west3 --limit 50
gcloud run revisions list --service pf-<owner>-t08-placefinder --region europe-west3
```

In der Konsole: Cloud Run → Dienst → *Metrics* (Anfragen nach Statuscode-Klasse, Latenz als 50., 95. und 99. Perzentil, Instanzen, CPU, Speicher). Das ist RED für den Dienst – ohne eine Zeile Code, aber nur an der Grenze von Cloud Run; die Spans in der Anwendung liefert erst OpenTelemetry.

## Ausprobieren

- Eine Einstellung ändern (z. B. `-var max_instances=3`) und den Plan lesen: Was ändert sich in place (`~`), was wird ersetzt (`-/+`)?
- In der Konsole etwas von Hand ändern, z. B. eine Lebenszyklusregel des Buckets löschen, und mit `plan` die Abweichung finden (Drift).
- `destroy` und `apply` hintereinander: Ist alles wieder gleich? Was hat sich geändert (Adressen, Namen)?
- `tools/tofu.sh t08-iac/infra state list` und `state show google_compute_network.main`

## Typische Probleme

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `No remote state yet` | `bootstrap-state.sh` fehlt | `t08-iac/bootstrap-state.sh` |
| `could not find default credentials` | OpenTofu findet keine Application Default Credentials | `gcloud auth application-default login --no-launch-browser` |
| `Error acquiring the state lock` | Ein anderer Lauf hält die Sperre oder ist abgebrochen. | warten; nach einem Abbruch `tofu force-unlock <id>` mit der ID aus der Meldung |
| `SERVICE_DISABLED` oder `has not been used in project` | Eine API ist gerade erst freigeschaltet worden. | eine Minute warten, `apply` wiederholen |
| Cloud Run: Image nicht gefunden | `:t08` fehlt auf ghcr.io oder ist privat | `t03-container/build-image.sh --push --tag t08`, Paket öffentlich machen |
| `/health` antwortet erst nach einer Minute | Beim ersten Start mit Datenbank lädt PlaceFinder die Orte. | warten; die Logs zeigen `Loaded … places` |
| Workflow: `Permission 'iam.serviceAccounts.getAccessToken' denied` | Repository oder Branch passt nicht zur Bedingung des Pools | `github_repository` genau wie auf GitHub, Branch `master` |
| `github-oidc`: Pool existiert schon (`ALREADY_EXISTS`) | Ein gelöschter Pool bleibt 30 Tage reserviert. | `-var pool_id=<neuer-name>` |

## Aufräumen

```bash
tools/tofu.sh t08-iac/github-oidc destroy -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/infra destroy
(cd t08-iac/local && tofu destroy)
t08-iac/destroy-state.sh      # erst am Kursende, nach allen anderen destroy-Aufrufen
tools/find-leftovers.sh
```

## Fragen zum Weiterdenken

- Was steht im State, und warum gehört er nicht ins Git-Repository? Wie schützt dieser Bucket ihn?
- Warum ist Workload Identity Federation sicherer als ein JSON-Schlüssel in den GitHub-Secrets?
- Welche Teile der Konfiguration sind anbieterspezifisch, welche ließen sich als Modul für alle drei Anbieter schreiben?
- Die Pipeline rollt aus, OpenTofu ignoriert das Image. Was ginge verloren, wenn OpenTofu auch das Image verwaltete – und was mit GitOps?
- Welches SLO würden Sie für PlaceFinder festlegen, und welche Metrik misst es?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| State-Backend | S3 mit Lock-Datei | Storage Account (Blob Lease) | Cloud Storage |
| Datenbank im privaten Netz | RDS in Subnetzen ohne Route ins Internet | Flexible Server mit delegiertem Subnetz und privater DNS-Zone | Cloud SQL mit privater IP über Private Services Access |
| Datenbank-Passwort | Secrets Manager, von RDS verwaltet | Secret der Container App | Secret Manager |
| Ausrollen ohne Schlüssel | IAM-OIDC-Anbieter + Rolle | Managed Identity + Federated Credential | Workload Identity Federation |
| Native IaC | CloudFormation, CDK | Bicep | Infrastructure Manager |
| Logs und Metriken | CloudWatch, X-Ray | Azure Monitor, Application Insights | Cloud Logging, Cloud Monitoring, Cloud Trace |
