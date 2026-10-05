# T03 – Registry und Serverless Container mit Cloud Run

**Ziel:** Das PlaceFinder-Image liegt in der Artifact Registry und läuft auf Cloud Run. Cloud Run startet Container für eingehende Anfragen, skaliert bis auf null und stellt eine HTTPS-Adresse mit Zertifikat bereit.

**Kosten:** Cloud Run: 2 Millionen Anfragen und ein Kontingent an vCPU- und GiB-Sekunden pro Monat kostenlos. Artifact Registry: 0,5 GB Speicher kostenlos – nicht mehr als ein, zwei Images aufbewahren.

## Voraussetzungen

- Docker im Dev Container
- Image `$PLACEFINDER_IMAGE:t03` (öffentlich auf ghcr.io oder lokal gebaut: `docker build -t ghcr.io/<user>/placefinder:t03 .`)

## Schritte

```bash
./push-image.sh                 # Repository anlegen, Image hochladen
./deploy.sh                     # Cloud-Run-Dienst anlegen, auf /health warten
```

`push-image.sh` legt das Docker-Repository `pf-<owner>-images` in `GCP_REGION` an und richtet `gcloud` als Credential Helper für Docker ein. `deploy.sh` startet den Dienst `pf-<owner>-placefinder` mit 1 vCPU, 512 MiB und 0 bis 2 Instanzen und erlaubt Aufrufe ohne Anmeldung (`--allow-unauthenticated`).

## Prüfen

```bash
url=$(grep SERVICE_URL ../.state/t03.env | cut -d= -f2)
curl "$url/health"
curl "$url/places?q=Berlin"
gcloud run services describe pf-<owner>-placefinder --region europe-west3
gcloud run services logs read pf-<owner>-placefinder --region europe-west3 --limit 20
```

In der Konsole unter *Cloud Run* zeigt der Reiter *Metrics* Anfragen, Latenz und die Zahl der Instanzen – nach einigen Minuten ohne Anfragen fällt sie auf null.

## Aufräumen

```bash
./destroy.sh     # Dienst und Repository
```

Wer in Termin 5 weiterarbeiten will, kann den Dienst stehen lassen – ohne Anfragen kostet er nichts.

## Fragen zum Weiterdenken

- Welche Kubernetes-Begriffe aus Termin 3 finden sich in Cloud Run wieder (Cloud Run nutzt die Knative-API)?
- Was kostet die Skalierung auf null an Antwortzeit, und wann ist `--min-instances 1` sinnvoll?
- Warum lädt Cloud Run das Image aus der Artifact Registry der eigenen Region statt direkt von ghcr.io?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Registry | Amazon ECR | Azure Container Registry (hier: ghcr.io) | Artifact Registry |
| Serverless Container | ECS Express Mode auf Fargate | Azure Container Apps | Cloud Run |
| Skalierung auf null | nein | ja | ja |
