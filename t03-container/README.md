# T03 – Kubernetes lokal, Registry und Serverless Container

Zwei Teile: In der Übung läuft PlaceFinder in einem lokalen Kubernetes-Cluster, den k3d im Dev Container anlegt. In der Selbstlernphase kommt das Image in die Artifact Registry und läuft auf **Cloud Run**.

## Teil 1: Kubernetes lokal mit k3d (Übung)

**Kosten:** keine – alles läuft im Dev Container. Drei Nodes brauchen zusammen rund 1,5 bis 2 GB Arbeitsspeicher; unter WSL ggf. die Grenze in `.wslconfig` erhöhen.

| Skript | Aufgabe |
|---|---|
| `cluster-up.sh` | Cluster `pf` anlegen (1 Server, 2 Agents, k3s 1.36, nur mit den nötigen Diensten) oder wieder starten |
| `build-image.sh` | Image `placefinder:<version>` aus `../placefinder` bauen und in die Nodes laden; mit `--push` zusätzlich als `:<version>` und `:t03` nach ghcr.io (Teil 2; `--tag t05` für den Stand von Termin 5) |
| `cluster-down.sh` | Cluster löschen; die Images bleiben in Docker |

```bash
cd /workspaces/cloud-labs-gcp/t03-container
./cluster-up.sh                         # beim ersten Mal 1–2 Minuten (k3s-Image laden)
./build-image.sh                        # placefinder:0.1.0, Version aus pyproject.toml
cd /workspaces/placefinder
kubectl apply --filename deploy/k8s/    # eigenes Manifest aus der Übung
kubectl get pods --output wide          # drei Pods, verteilt auf die Nodes
kubectl port-forward svc/placefinder 8000:80
```

Wie es weitergeht – neue Version ausrollen, Konfiguration ändern, Helm-Chart, Autoscaler – steht im README von PlaceFinder, Abschnitt *Kubernetes*. Die Musterlösung liegt im Tag `t03` von PlaceFinder: `git fetch upstream --tags`, dann `git diff t03 -- deploy/` (`upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose)).

**Typische Probleme**

- `ErrImagePull` oder `ImagePullBackOff`: Das Image ist nicht in den Nodes. `./build-image.sh` nach `./cluster-up.sh` ausführen; Tag im Manifest und Version müssen übereinstimmen.
- Pods bleiben `Pending`: zu wenig Speicher, `kubectl describe pod <name>` zeigt den Grund.
- Nach einem Neubau des Dev Containers kennt `kubectl` den Cluster nicht mehr: `./cluster-up.sh` startet ihn und trägt ihn wieder ein.
- `kubectl get pods --all-namespaces` zeigt nur `coredns`, `metrics-server` und `local-path-provisioner` in `kube-system`, kein `traefik` oder `svclb-…`: So ist es gewollt. `cluster-up.sh` schaltet Traefik, ServiceLB, den Helm-Controller, den NetworkPolicy-Controller und den Load Balancer von k3d ab, weil die Übung sie nicht braucht; Zugang von außen folgt in [t04-netzwerk](../t04-netzwerk/README.md). Ein früher angelegter Cluster behält sie, bis er mit `./cluster-down.sh` und `./cluster-up.sh` neu entsteht.

Aufräumen nach der Selbstlernphase: `./cluster-down.sh`.

## Teil 2: Registry und Cloud Run (Selbstlernphase)

**Ziel:** Das PlaceFinder-Image liegt in der Artifact Registry und läuft auf Cloud Run. Cloud Run startet Container für eingehende Anfragen, skaliert bis auf null und stellt eine HTTPS-Adresse mit Zertifikat bereit.

**Kosten:** Cloud Run: 2 Millionen Anfragen und ein Kontingent an vCPU- und GiB-Sekunden pro Monat kostenlos. Artifact Registry: 0,5 GB Speicher kostenlos – nicht mehr als ein, zwei Images aufbewahren.

### Voraussetzungen

- Docker im Dev Container
- Image `$PLACEFINDER_IMAGE:t03` auf ghcr.io: `./build-image.sh --push`, danach das Paket auf GitHub öffentlich machen (*Packages* → *placefinder* → *Package settings* → *Change visibility*). Das Skript prüft, ob das geklappt hat.

### Schritte

```bash
./push-image.sh                 # Repository anlegen, Image hochladen
./deploy.sh                     # Cloud-Run-Dienst anlegen, auf /health warten
```

`push-image.sh` legt das Docker-Repository `pf-<owner>-images` in `GCP_REGION` an und richtet `gcloud` als Credential Helper für Docker ein. `deploy.sh` startet den Dienst `pf-<owner>-placefinder` mit 1 vCPU, 512 MiB und 0 bis 2 Instanzen und erlaubt Aufrufe ohne Anmeldung (`--allow-unauthenticated`).

### Prüfen

```bash
url=$(grep SERVICE_URL ../.state/t03.env | cut --delimiter = --fields 2)
curl "$url/health"
curl "$url/places?q=Erfurt"
gcloud run services describe pf-<owner>-placefinder --region europe-west3
gcloud run services logs read pf-<owner>-placefinder --region europe-west3 --limit 20
```

In der Konsole unter *Cloud Run* zeigt der Reiter *Metrics* Anfragen, Latenz und die Zahl der Instanzen – nach einigen Minuten ohne Anfragen fällt sie auf null.

### Aufräumen

```bash
./destroy.sh     # Dienst und Repository
```

Wer in Termin 5 weiterarbeiten will, kann den Dienst stehen lassen – ohne Anfragen kostet er nichts.

### Fragen zum Weiterdenken

- Welche Kubernetes-Begriffe aus Termin 3 finden sich in Cloud Run wieder (Cloud Run nutzt die Knative-API)?
- Was kostet die Skalierung auf null an Antwortzeit, und wann ist `--min-instances 1` sinnvoll?
- Warum lädt Cloud Run das Image aus der Artifact Registry der eigenen Region statt direkt von ghcr.io?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Registry | Amazon ECR | Azure Container Registry (hier: ghcr.io) | Artifact Registry |
| Serverless Container | ECS Express Mode auf Fargate | Azure Container Apps | Cloud Run |
| Skalierung auf null | nein | ja | ja |
