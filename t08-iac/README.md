# T08 – Infrastruktur als Code mit OpenTofu

**Ziel:** Die Infrastruktur der Zwischenpräsentation entsteht reproduzierbar aus Code: Netz, Bucket, Artifact Registry und PlaceFinder auf Cloud Run, optional mit Datenbank. Der State liegt versioniert in Cloud Storage. Außerdem darf eine GitHub-Actions-Pipeline ohne gespeicherten Schlüssel Images bauen und ausrollen (Workload Identity Federation).

**Kosten:** Cloud Run, Netz und Registry liegen im Freikontingent bzw. kosten Cent-Beträge. Mit Datenbank zusätzlich ca. 0,35 USD pro Tag. Nach dem Test `destroy` ausführen.

## Voraussetzungen

- OpenTofu ab 1.10 (`tofu version`)
- `gcloud auth login` und `gcloud auth application-default login` aktiv, `config.env` ausgefüllt
- Öffentliches Image `$PLACEFINDER_IMAGE:t07` auf ghcr.io (oder ein anderer Tag über `-var image_tag=…`)

## 1. Remote State einrichten (einmalig)

```bash
./bootstrap-state.sh
```

Das Skript legt einen versionierten, privaten Bucket `pf-<owner>-<suffix>-tfstate` an und schreibt `../.state/backend.hcl`. Das Backend `gcs` sperrt den State selbst über eine Lock-Datei im Bucket. Der Bucket wird mit der CLI angelegt, weil OpenTofu seinen eigenen State-Speicher nicht verwalten kann, bevor es ihn gibt (Henne-Ei-Problem).

## 2. Infrastruktur ausrollen

```bash
cd ..
tools/tofu.sh t08-iac/infra plan      # beim ersten Aufruf mit init
tools/tofu.sh t08-iac/infra apply
tools/tofu.sh t08-iac/infra output
```

`tools/tofu.sh` setzt die Variablen `prefix`, `owner`, `suffix`, `project`, `region`, `placefinder_image` und `admin_cidrs` (eigene IP-Adresse) aus `config.env` und verwendet für jeden Ordner einen eigenen State-Pfad im Bucket. OpenTofu meldet sich mit den Application Default Credentials an.

| Datei | Inhalt |
|---|---|
| `infra/network.tf` | APIs, VPC mit Subnetzen und Firewall-Regeln wie in Termin 4 |
| `infra/storage.tf` | Bucket für Daten, Artifact-Registry-Repository mit Aufräumregel, Remote Repository für ghcr.io |
| `infra/service.tf` | Service Account und PlaceFinder auf Cloud Run |
| `infra/database.tf` | optional: Cloud SQL for PostgreSQL (`-var enable_database=true`) |
| `infra/outputs.tf` | URL, Dienstname, Bucket, Repository, Verbindungszeichenkette |

Cloud Run lädt Images nur aus der Artifact Registry oder von Docker Hub. Damit das Image von ghcr.io nicht erst kopiert werden muss, legt die Konfiguration ein **Remote Repository** an: Es holt das Image beim ersten Zugriff von ghcr.io und hält eine Kopie vor (Pull-Through-Cache).

Mit Datenbank:

```bash
tools/tofu.sh t08-iac/infra apply -var enable_database=true
tools/tofu.sh t08-iac/infra output -raw database_url
```

Die Datenbank ist wie in Termin 6 nur von der eigenen IP-Adresse aus erreichbar. Den Dienst mit der Datenbank zu verbinden, ist Teil der Übung: Am einfachsten bindet Cloud Run die Instanz über den Cloud SQL Auth Proxy ein (`volumes` mit `cloud_sql_instance` im Template, Rolle *Cloud SQL Client* für den Service Account), und das Passwort gehört in den Secret Manager statt in eine Umgebungsvariable.

### Ausprobieren

- Eine Einstellung ändern (z. B. `max_instance_count`) und `plan` lesen: Was ändert sich, was wird ersetzt?
- In der Konsole etwas von Hand ändern und mit `plan` die Abweichung (Drift) finden.
- `destroy` und `apply` hintereinander ausführen: Ist alles wieder gleich?

## 3. GitHub Actions ohne Schlüssel (Workload Identity Federation)

```bash
tools/tofu.sh t08-iac/github-oidc apply -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/github-oidc output
```

Die Konfiguration legt einen Workload Identity Pool mit einem Anbieter für `token.actions.githubusercontent.com` an. Nur Workflows auf dem Branch `master` des genannten Repositorys erhalten ein kurzlebiges Token für den Service Account `pf-<owner>-github-deploy`. Er darf Images in die Artifact Registry schieben und neue Cloud-Run-Revisionen ausrollen.

Gelöschte Pools bleiben 30 Tage lang reserviert. Wer `github-oidc` abgebaut hat und neu anlegen will, wählt einen anderen Namen: `-var pool_id=pf-<owner>-github2`.

In den eigenen PlaceFinder-Fork übernehmen:

1. `deploy.example.yml` als `.github/workflows/deploy.yml`
2. Repository-Variablen (*Settings* → *Secrets and variables* → *Actions* → *Variables*): `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `GCP_REGION` aus `github-oidc`, `IMAGE_REPOSITORY` (`image_repository`) und `SERVICE_NAME` (`service_name`) aus `infra`

Rollt die Pipeline ein neues Image aus, weicht der Dienst von der OpenTofu-Konfiguration ab; das nächste `apply` würde wieder das Image aus `image_tag` setzen. Für den Kurs ist das ein gutes Beispiel für Drift – in echten Projekten übernimmt entweder die Pipeline oder OpenTofu das Image, nicht beide.

## Aufräumen

```bash
tools/tofu.sh t08-iac/github-oidc destroy -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/infra destroy
t08-iac/destroy-state.sh      # erst am Kursende, nach allen anderen destroy-Aufrufen
```

## Fragen zum Weiterdenken

- Was steht im State, und warum gehört er nicht ins Git-Repository?
- Warum ist Workload Identity Federation sicherer als ein JSON-Schlüssel in den GitHub-Secrets?
- Welche Teile der Konfiguration sind anbieterspezifisch, welche ließen sich als Modul für alle drei Anbieter schreiben?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| State-Backend | S3 mit Lock-Datei | Storage Account (Blob Lease) | Cloud Storage |
| Keyless CI/CD | IAM-OIDC-Anbieter + Rolle | Managed Identity + Federated Credential | Workload Identity Federation |
| Native IaC | CloudFormation, CDK | Bicep | Infrastructure Manager |
