# T02 – PlaceFinder auf einer VM (IaaS)

**Ziel:** PlaceFinder v0 läuft auf einer Compute-Engine-VM. Die VM richtet sich beim ersten Start selbst ein (cloud-init): Pakete installieren, Code klonen, Abhängigkeiten mit uv installieren, GeoNames-Daten laden, Dienst starten. So wird sichtbar, was bei IaaS alles in der eigenen Verantwortung liegt.

**Kosten:** Eine `e2-micro` mit 30 GB Standard-Persistent-Disk ist in `us-west1`, `us-central1` und `us-east1` dauerhaft kostenlos. Die externe IP-Adresse kostet wenige Cent pro Tag aus dem Guthaben. Nach der Übung löschen.

## Voraussetzungen

- `t01-grundlagen` erledigt, `gcloud` angemeldet
- SSH-Schlüssel: `ssh-keygen -t ed25519` (Pfad in `config.env`, `SSH_PUBLIC_KEY`)
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
ssh ubuntu@<ip> journalctl -u placefinder -n 50
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

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| VM | EC2 `t3.micro` | Virtual Machines `Standard_B1s` | Compute Engine `e2-micro` |
| Firewall | Security Group | Network Security Group | VPC-Firewall-Regel |
| Startskript | User Data (cloud-init) | Custom Data (cloud-init) | Metadaten `user-data` (cloud-init) |
