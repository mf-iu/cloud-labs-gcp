# T11 – Modell als Service

**Ziel:** Das Modell zur Einwohnerschätzung aus Termin 11 wird als Endpunkt `/estimate` von PlaceFinder bereitgestellt. MLflow speichert Experimente lokal und Artefakte in Cloud Storage; das freigegebene Modell liegt unter `models/` im selben Bucket. Der Dienst darf über seinen Service Account den Bucket nur lesen.

**Kosten:** Cloud Run mit 1 vCPU und 1 GiB im Freikontingent, solange nur wenige Anfragen kommen. Managed-ML-Plattformen (Vertex AI) werden nur vorgestellt, weil schon kleine Endpunkte dauerhaft laufen und deutlich mehr kosten.

## Schritte

```bash
cd ..
tools/tofu.sh t11-ml/infra apply           # Bucket, Service Account, Dienst mit Image :t11
tools/tofu.sh t11-ml/infra output
```

Wie in Termin 8 lädt Cloud Run das Image über ein Remote Repository der Artifact Registry von ghcr.io.

MLflow lokal mit Artefakten in Cloud Storage (Zugangsdaten aus `gcloud auth application-default login`):

```bash
bucket=$(tools/tofu.sh t11-ml/infra output -raw bucket)
uvx --with google-cloud-storage mlflow server --backend-store-uri sqlite:///.state/mlflow.db \
  --artifacts-destination "gs://$bucket/mlflow" --port 5000
```

Training im Notebook von Termin 11 mit `mlflow.set_tracking_uri("http://localhost:5000")`. Das beste Modell exportieren und hochladen:

```bash
t11-ml/upload-model.sh model.joblib       # rollt eine neue Revision aus, damit sie das Modell lädt
curl "$(tools/tofu.sh t11-ml/infra output -raw service_url)/estimate?lat=50.98&lon=11.03"
```

PlaceFinder liest beim Start `MODEL_URI` (z. B. `gs://…/models/estimate/model.joblib`) mit den Rechten des Service Accounts. `upload-model.sh` setzt dazu die Umgebungsvariable `MODEL_UPLOADED`; das erzeugt eine neue Revision, und neue Instanzen laden das Modell. Auch das ist eine Änderung außerhalb von OpenTofu – das nächste `plan` zeigt sie als Drift.

## Aufräumen

```bash
tools/tofu.sh t11-ml/infra destroy
```

## Fragen zum Weiterdenken

- Welche Informationen braucht man, um ein Modell später nachvollziehen zu können (Daten, Code, Parameter, Metriken)?
- Wie würde man ein neues Modell mit Traffic Splitting schrittweise ausrollen und mit dem alten vergleichen?
- Was kostet ein Endpunkt in Vertex AI im Vergleich, und wann lohnt er sich?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| ML-Plattform | SageMaker AI | Azure Machine Learning | Vertex AI |
| Modell-Endpunkt hier | ECS Express Mode | Container Apps | Cloud Run |
| Rechte des Dienstes | Task Role | Managed Identity | Service Account |
