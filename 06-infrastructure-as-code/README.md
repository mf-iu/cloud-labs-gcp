# 06 – Infrastruktur als Code: base und service

**Ziel:** Die Infrastruktur der Zwischenpräsentation entsteht beim neuen Anbieter reproduzierbar aus OpenTofu-Code mit Remote State – in zwei Teilen:

- **`base`** – APIs, VPC aus Termin 4, Bucket aus Termin 7, Remote Repository vor ghcr.io, Dienstkonto von PlaceFinder. Entsteht einmal in Termin 8 und bleibt bis zum Kursende; kostet praktisch nichts.
- **`service`** – PlaceFinder auf Cloud Run, optional Cloud SQL for PostgreSQL. Liest die Ausgaben von `base` und wird im Termin angelegt und wieder gelöscht.

Die Function, der Data Lake, ML und das Abschlussprojekt bauen später ebenfalls auf `base` auf. Ein Workflow im eigenen Fork rollt neue Images ohne gespeicherte Zugangsschlüssel aus. Lokal gehören dazu OpenTofu mit Docker, die Pipeline im eigenen Fork und die Beobachtbarkeit mit Grafana: [cloud-labs-local/08-iac-and-operations](https://github.com/mf-iu/cloud-labs-local/tree/master/08-iac-and-operations).

| Ordner oder Datei | Aufgabe |
|---|---|
| `bootstrap-state.sh`, `destroy-state.sh` | Bucket für den Remote State anlegen bzw. am Kursende löschen |
| `base/` | APIs, VPC aus Termin 4, Bucket aus Termin 7, Remote Repository vor ghcr.io, Dienstkonto von PlaceFinder; bleibt bis zum Kursende |
| `service/` | PlaceFinder auf Cloud Run, optional Cloud SQL for PostgreSQL; im Termin anlegen und löschen |
| `github-oidc/` | Vertrauensstellung für GitHub Actions: Workload Identity Pool und Dienstkonto, das nur der eigene Fork nutzen darf |
| `deploy.example.yml` | Workflow für den eigenen Fork: Image aus der Pipeline per Digest ausrollen, Smoke-Test |

**Kosten:** `base` kostet praktisch nichts und darf bis zum Kursende bestehen bleiben. `service`: Cloud Run bleibt im Freikontingent, das zwischengespeicherte Image in Artifact Registry ebenfalls (0,5 GB). Cloud SQL `db-f1-micro` ca. 0,015 USD pro Stunde aus dem Guthaben. **Nach dem Test `destroy` ausführen.**

## Voraussetzungen

- Dev Container dieses Repositorys mit OpenTofu ab 1.10 (`../cloud-labs-local/tools/check-tools.sh`)
- Projekt beim neuen Anbieter eingerichtet (Schritt `01-account` mit dem [Anbieterwechsel](../01-account/README.md#anbieterwechsel)), `gcloud auth login` und `gcloud auth application-default login` aktiv – OpenTofu meldet sich mit den Application Default Credentials an –, `config.env` ausgefüllt
- Image `$PLACEFINDER_IMAGE:t08` öffentlich auf ghcr.io: `../cloud-labs-local/02-container/publish-image.sh --tag t08` oder die Pipeline des Forks, danach das Paket auf GitHub öffentlich machen

## 1. Remote State einrichten (einmalig)

```bash
cd /workspaces/cloud-labs-gcp
06-infrastructure-as-code/bootstrap-state.sh
```

Das Skript legt einen versionierten, privaten Bucket `pf-<owner>-<suffix>-tfstate` an und schreibt `.state/backend.hcl`. Gesperrt wird der State über eine Lock-Datei im Bucket. Den Bucket legt die CLI an, weil OpenTofu seinen State-Speicher nicht verwalten kann, bevor es ihn gibt (Henne-Ei-Problem).

## 2. base anlegen (einmalig, bleibt bis zum Kursende)

```bash
tools/tofu.sh 06-infrastructure-as-code/base plan      # beim ersten Aufruf mit init
tools/tofu.sh 06-infrastructure-as-code/base apply
tools/tofu.sh 06-infrastructure-as-code/base output
```

`tools/tofu.sh` setzt die Variablen `prefix`, `owner`, `suffix`, `project`, `region` und `placefinder_image` aus `config.env` und verwendet für jeden Ordner ein eigenes Präfix im State-Bucket, z. B. `06-infrastructure-as-code/base/default.tfstate`. Dazu kommt `backend` mit den Einstellungen aus `.state/backend.hcl`: Damit liest `service` die Ausgaben von `base` (`terraform_remote_state`).

| Datei | Inhalt |
|---|---|
| `base/network.tf` | APIs, VPC mit Subnetzen `public` und `app` wie in Termin 4, Firewall-Regeln mit Netzwerk-Tags |
| `base/storage.tf` | privater Bucket mit CORS und Lebenszyklusregeln wie in Termin 7; Remote Repository in Artifact Registry vor ghcr.io |
| `base/service-account.tf` | Dienstkonto von PlaceFinder mit Rechten auf den Bucket |
| `base/outputs.tf` | Netz, Subnetz, Bucket, Image-Repository und Dienstkonto für `service` und spätere Konfigurationen |

**Warum ein Remote Repository?** Cloud Run lädt Images nur aus Artifact Registry (und Docker Hub), nicht von ghcr.io. Ein Remote Repository steht als Zwischenspeicher davor: Cloud Run fragt dort, Artifact Registry holt das Image beim ersten Mal von ghcr.io. Niemand muss etwas hochladen.

## 3. service anlegen, prüfen, löschen (im Termin)

```bash
tools/tofu.sh 06-infrastructure-as-code/service plan
tools/tofu.sh 06-infrastructure-as-code/service apply     # ca. 5 Minuten
tools/tofu.sh 06-infrastructure-as-code/service output
curl "$(tools/tofu.sh 06-infrastructure-as-code/service output -raw service_url)/health"
tools/tofu.sh 06-infrastructure-as-code/service destroy   # am Ende des Termins
```

`service/base.tf` liest die Ausgaben von `base` aus dessen State (`terraform_remote_state`): Netz, Subnetze, Speicher und was der Dienst sonst braucht. `service` legt also nichts doppelt an und kann jederzeit gelöscht werden, ohne `base` anzutasten.

| Datei | Inhalt |
|---|---|
| `service/base.tf` | liest die Ausgaben von `base` (`terraform_remote_state`) |
| `service/service.tf` | PlaceFinder auf Cloud Run mit Direct VPC Egress ins Subnetz `app` von `base` |
| `service/database.tf` | optional: reservierter Bereich `10.20.20.0/24` und Peering zu Google, Cloud SQL for PostgreSQL 18 mit privater Adresse, Passwort in Secret Manager |
| `service/outputs.tf` | URL und Name des Dienstes, Image-Repository, Datenbank |

### Mit Datenbank

```bash
tools/tofu.sh 06-infrastructure-as-code/service apply -var enable_database=true    # ca. 15 Minuten mehr
curl "$(tools/tofu.sh 06-infrastructure-as-code/service output -raw service_url)/health"   # "places": 34000 und mehr
```

Verwaltete Datenbanken laufen bei Google in einem eigenen Netz. *Private Services Access* reserviert dafür den Bereich `10.20.20.0/24` des VPC und verbindet beide Netze per Peering; Cloud SQL bekommt eine Adresse aus diesem Bereich und keine öffentliche. Cloud Run schickt Verkehr in private Bereiche über das Subnetz `app` (Direct VPC Egress) mit dem Netzwerk-Tag `app`; die Firewall erlaubt von dort nur PostgreSQL zur Datenbank. Vom eigenen Rechner aus ist sie nicht erreichbar, `load-cities.sh` geht also nicht. Stattdessen lädt PlaceFinder beim ersten Start die Orte aus dem Image (`DATABASE_INIT=true`).

Das Passwort erzeugt OpenTofu (`random_password`) und legt es in Secret Manager ab; nur das Dienstkonto von PlaceFinder darf es lesen. Cloud Run gibt es als `PGPASSWORD` an PlaceFinder, die Verbindungszeichenkette `DATABASE_URL` enthält kein Passwort. Im State steht es aber – ein Grund, warum der State privat und verschlüsselt liegt. Ganz ohne Passwort ginge es mit der IAM-Anmeldung von Cloud SQL.

## 4. Ausrollen aus der Pipeline, ohne Schlüssel

```bash
tools/tofu.sh 06-infrastructure-as-code/github-oidc apply -var github_repository=<github-user>/placefinder
tools/tofu.sh 06-infrastructure-as-code/github-oidc output
```

Die Konfiguration legt einen Workload Identity Pool mit einem Anbieter für GitHub Actions an. Die Bedingung lässt nur Tokens des genannten Repositorys und des Branches `master` zu. Damit darf der Workflow als Dienstkonto `pf-<owner>-github-deploy` handeln: Cloud-Run-Revisionen ausrollen (*Cloud Run Developer*) und dabei das Dienstkonto von PlaceFinder aus `base` verwenden – sonst nichts. Ein gelöschter Pool bleibt 30 Tage reserviert; nach einem `destroy` mit `-var pool_id=<neuer-name>` arbeiten.

Im eigenen PlaceFinder-Fork:

1. `deploy.example.yml` als `.github/workflows/deploy.yml` übernehmen, committen, pushen.
2. Repository-Variablen anlegen (*Settings* → *Secrets and variables* → *Actions* → *Variables*): `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` und `GCP_REGION` aus `github-oidc`, `SERVICE_NAME`, `IMAGE_REPOSITORY` und `SERVICE_URL` (Ausgabe `service_url`) aus `service`.
3. Eine kleine Änderung pushen. Nach der grünen Pipeline startet `deploy`: Image per Digest als neue Revision ausrollen (ca. eine Minute), dann der Smoke-Test aus Termin 5.

**Pipeline und OpenTofu:** `image_tag` bestimmt nur das erste Image. Danach rollt die Pipeline aus; `ignore_changes` in `service.tf` verhindert, dass das nächste `apply` auf `image_tag` zurücksetzt. Jede Eigenschaft gehört genau einem Werkzeug.

## 5. Logs und Metriken beim Anbieter

```bash
gcloud run services logs read pf-<owner>-t08-placefinder --region europe-west3 --limit 50
gcloud run revisions list --service pf-<owner>-t08-placefinder --region europe-west3
```

In der Konsole: Cloud Run → Dienst → *Metrics* (Anfragen nach Statuscode-Klasse, Latenz als 50., 95. und 99. Perzentil, Instanzen, CPU, Speicher). Das ist RED für den Dienst – ohne eine Zeile Code, aber nur an der Grenze von Cloud Run; die Spans in der Anwendung liefert erst OpenTelemetry.

## Ausprobieren

- Eine Einstellung ändern (z. B. `-var max_instances=3`) und den Plan lesen: Was ändert sich in place (`~`), was wird ersetzt (`-/+`)?
- In der Konsole etwas von Hand ändern, z. B. eine Lebenszyklusregel des Buckets löschen, und mit `plan` die Abweichung finden (Drift).
- `destroy` und `apply` hintereinander: Ist alles wieder gleich? Was hat sich geändert (Adressen, Namen)?
- `tools/tofu.sh 06-infrastructure-as-code/base state list` und `state show google_compute_network.main`; `tools/tofu.sh 06-infrastructure-as-code/service state show data.terraform_remote_state.base`
- `base` ändern und `service` neu planen: Was sieht `service` von der Änderung, ohne dass sich sein eigener Code ändert?

## Typische Probleme

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `No remote state yet` | `bootstrap-state.sh` fehlt | `06-infrastructure-as-code/bootstrap-state.sh` |
| `could not find default credentials` | OpenTofu findet keine Application Default Credentials | `gcloud auth application-default login --no-launch-browser` |
| `Error acquiring the state lock` | Ein anderer Lauf hält die Sperre oder ist abgebrochen. | warten; nach einem Abbruch `tofu force-unlock <id>` mit der ID aus der Meldung |
| `SERVICE_DISABLED` oder `has not been used in project` | Eine API ist gerade erst freigeschaltet worden. | eine Minute warten, `apply` wiederholen |
| Cloud Run: Image nicht gefunden | `:t08` fehlt auf ghcr.io oder ist privat | `../cloud-labs-local/02-container/publish-image.sh --tag t08`, Paket öffentlich machen |
| `/health` antwortet erst nach einer Minute | Beim ersten Start mit Datenbank lädt PlaceFinder die Orte. | warten; die Logs zeigen `Loaded … places` |
| Workflow: `Permission 'iam.serviceAccounts.getAccessToken' denied` | Repository oder Branch passt nicht zur Bedingung des Pools | `github_repository` genau wie auf GitHub, Branch `master` |
| `github-oidc`: Pool existiert schon (`ALREADY_EXISTS`) | Ein gelöschter Pool bleibt 30 Tage reserviert. | `-var pool_id=<neuer-name>` |
| `service`: `Unable to find remote state` oder fehlende Ausgaben von `base` | `base` ist noch nicht angelegt oder gelöscht | `tools/tofu.sh 06-infrastructure-as-code/base apply` |

## Aufräumen

Nach jedem Termin:

```bash
tools/tofu.sh 06-infrastructure-as-code/service destroy
```

Am Kursende, nach den Konfigurationen der späteren Termine:

```bash
tools/tofu.sh 06-infrastructure-as-code/github-oidc destroy -var github_repository=<github-user>/placefinder
tools/tofu.sh 06-infrastructure-as-code/base destroy
06-infrastructure-as-code/destroy-state.sh      # nach allen anderen destroy-Aufrufen
tools/find-leftovers.sh
```

## Fragen zum Weiterdenken

- Was steht im State, und warum gehört er nicht ins Git-Repository? Wie schützt dieser Bucket ihn?
- Warum ist Workload Identity Federation sicherer als ein JSON-Schlüssel in den GitHub-Secrets?
- Welche Teile der Konfiguration sind anbieterspezifisch, welche ließen sich als Modul für alle drei Anbieter schreiben?
- Die Pipeline rollt aus, OpenTofu ignoriert das Image. Was ginge verloren, wenn OpenTofu auch das Image verwaltete – und was mit GitOps?
- Welches SLO würden Sie für PlaceFinder festlegen, und welche Metrik misst es?
- Was gehört in `base`, was in `service`? Woran erkennt man, dass eine Ressource zwischen den Terminen bestehen bleiben darf?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| State-Backend | S3 mit Lock-Datei | Storage Account (Blob Lease) | Cloud Storage |
| Datenbank im privaten Netz | RDS in Subnetzen ohne Route ins Internet | Flexible Server mit delegiertem Subnetz und privater DNS-Zone | Cloud SQL mit privater IP über Private Services Access |
| Datenbank-Passwort | Secrets Manager, von RDS verwaltet | Secret der Container App | Secret Manager |
| Ausrollen ohne Schlüssel | IAM-OIDC-Anbieter + Rolle | Managed Identity + Federated Credential | Workload Identity Federation |
| Native IaC | CloudFormation, CDK | Bicep | Infrastructure Manager |
| Logs und Metriken | CloudWatch, X-Ray | Azure Monitor, Application Insights | Cloud Logging, Cloud Monitoring, Cloud Trace |
