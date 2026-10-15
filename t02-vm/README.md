# T02 – PlaceFinder auf einer VM (IaaS)

**Ziel:** PlaceFinder v0 läuft auf einer Compute-Engine-VM. Die VM richtet sich beim ersten Start selbst ein (cloud-init): Pakete installieren, Code klonen, Abhängigkeiten mit uv installieren, GeoNames-Daten laden, Dienst starten. So wird sichtbar, was bei IaaS alles in der eigenen Verantwortung liegt.

**Kosten:** Eine `e2-micro` mit 30 GB Standard-Persistent-Disk ist in `us-west1`, `us-central1` und `us-east1` dauerhaft kostenlos. Die externe IP-Adresse kostet wenige Cent pro Tag aus dem Guthaben. Nach der Übung löschen.

## Voraussetzungen

- `t01-grundlagen` erledigt, `gcloud` angemeldet
- SSH-Schlüssel `~/.ssh/id_ed25519`, einmalig im **Ubuntu-Terminal von WSL** angelegt, nicht im Container (siehe [t01-grundlagen](../t01-grundlagen/README.md#ssh-schlüssel-für-die-vms))
- PlaceFinder-Fork mit dem Tag `t01` unter `PLACEFINDER_REPO` (öffentlich lesbar)

## Schritte

```bash
./create-vm.sh          # oder: ./create-vm.sh <tag/branch>, Standard t01
```

Das Skript

1. schaltet die Compute Engine API ein (beim ersten Mal eine Minute),
2. legt im Netz `default` eine Firewall-Regel an, die SSH (22) und die API (8000) nur von der eigenen IP-Adresse zulässt – für alle VMs mit dem Netzwerk-Tag `pf-<owner>-t02-vm`,
3. erstellt die VM mit Ubuntu 24.04, `cloud-init.yaml` als Metadatum `user-data` und dem eigenen SSH-Schlüssel für den Benutzer `ubuntu`,
4. wartet, bis die API antwortet (die kleine VM braucht beim ersten Start 5–10 Minuten).

## Prüfen

```bash
ssh ubuntu@<ip> cloud-init status --wait
ssh ubuntu@<ip> journalctl --unit placefinder --lines 50
curl "http://<ip>:8000/places?q=Erfurt"
gcloud compute instances get-serial-port-output pf-<owner>-t02-vm --zone us-central1-a | tail
```

## Aufräumen

```bash
./destroy-vm.sh
```

## Fragen zum Weiterdenken

- Was müsste man hier selbst erledigen, was eine PaaS wie App Engine oder Cloud Run übernimmt?
- Warum hängen Firewall-Regeln bei Google Cloud an Netzwerk-Tags statt direkt an der VM?
- Was passiert mit der Anwendung, wenn die VM neu startet? Und wenn sie gelöscht und neu angelegt wird?

## Container und Compose

Die Container-Übungen von Termin 2 hängen nicht vom Anbieter ab. Sie stehen in der README von PlaceFinder, Abschnitt *Container* (Musterlösung ab Tag `t02`):

- Dockerfile und `.dockerignore` schreiben, Image bauen, starten, Schichten ansehen (Übung im Termin)
- `compose.yaml` mit PlaceFinder und einem kleinen Übungsdienst (Selbstlernphase); eine Datenbank folgt in Termin 6
- optional: Image verkleinern und mit Trivy scannen; Image in die GitHub Container Registry laden (für Termin 3 nötig)

Alle Container-Befehle laufen im **Dev Container** (`cd /workspaces/placefinder`). Er hat eine eigene Docker Engine. Ob eine Anmeldung bei Docker Hub nötig ist und was bei `toomanyrequests` hilft, steht im README von PlaceFinder unter [Docker Hub: anmelden oder nicht?](https://github.com/mf-iu/placefinder#docker-hub-anmelden-oder-nicht).

Die Musterlösung holt man so in den eigenen Fork:

```bash
cd /workspaces/placefinder
git remote add upstream https://github.com/mf-iu/placefinder.git   # einmalig
git fetch upstream --tags
git diff t02 -- Dockerfile compose.yaml      # eigene Lösung mit der Musterlösung vergleichen
```

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| VM | EC2 `t3.micro` | Virtual Machines `Standard_B1s` | Compute Engine `e2-micro` |
| Firewall | Security Group | Network Security Group | VPC-Firewall-Regel |
| Startskript | User Data (cloud-init) | Custom Data (cloud-init) | Metadaten `user-data` (cloud-init) |
