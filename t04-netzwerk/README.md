# T04 – Netze: VPC in Google Cloud, Diagnose, Gateway API lokal

Die Selbstlernphase von Termin 4 hat drei Teile: Der Netzentwurf aus der Übung wird als VPC in Google Cloud angelegt und mit zwei Test-VMs geprüft (Aufgabe 1), `diagnose.sh` zeigt den Weg einer HTTPS-Anfrage (Aufgabe 2), und die Demo mit Gateway API und cert-manager läuft im lokalen k3d-Cluster (Aufgaben 3 und 4).

| Skript | Aufgabe |
|---|---|
| `create-vpc.sh` | VPC mit Subnetzen und Firewall-Regeln anlegen; optional Test-VMs und Cloud NAT |
| `check-vpc.sh` | Test-VMs prüfen: Was ist von wo erreichbar? |
| `destroy-vpc.sh` | alles wieder löschen |
| `diagnose.sh` | DNS, TCP, TLS und Zertifikat eines Hosts anzeigen |
| `gateway-up.sh`, `gateway-down.sh` | lokaler Cluster mit Gateway API, cert-manager und PlaceFinder über HTTPS (Dateien in `k8s/`) |

## Teil 1: VPC mit Subnetzen und Firewall-Regeln

**Ziel:** drei regionale Subnetze für öffentliche Dienste, Anwendung und Datenbank und Firewall-Regeln, die über Netzwerk-Tags festlegen, wer wen erreichen darf.

**Kosten:** VPC, Subnetze und Firewall-Regeln sind kostenlos. Die beiden optionalen Test-VMs (`e2-micro` in `GCP_ZONE`) kosten in Frankfurt zusammen wenige Cent pro Stunde. Das optionale **Cloud NAT kostet je VM 0,0014 USD pro Stunde (höchstens 0,044 USD), dazu 0,005 USD pro Stunde für seine IP-Adresse und 0,045 USD je GB** – für die eine private VM nur wenige Cent pro Tag, trotzdem am selben Tag wieder löschen.

### Aufbau

| Subnetz | CIDR | Besonderheit |
|---|---|---|
| pf-<owner>-public | 10.20.0.0/24 | VMs mit externer IP-Adresse |
| pf-<owner>-app | 10.20.10.0/24 | Private Google Access; mit `--with-nat` Internetzugang über Cloud NAT |
| pf-<owner>-db | 10.20.20.0/24 | Private Google Access |

| Firewall-Regel | Erlaubt | Ziel (Tag) |
|---|---|---|
| allow-https | 443 von überall | `lb` |
| allow-api | 8000 von VMs mit Tag `lb` | `app` |
| allow-postgres | 5432 von VMs mit Tag `app` | `db` |
| allow-ssh (mit `--with-vm`) | 22 von der eigenen IP-Adresse | `ssh` (Bastion-Host) |
| allow-ssh-from-bastion (mit `--with-vm`) | 22 von VMs mit Tag `ssh` | `app` (private VM) |

Besonderheiten von Google Cloud: Die VPC ist **global**, die Subnetze sind regional und reichen über alle Zonen. „Öffentlich“ ist nicht das Subnetz, sondern eine VM mit externer IP-Adresse. Ohne eigene Regeln verbietet eine VPC jeden eingehenden und erlaubt jeden ausgehenden Verkehr; ausgehend ins Internet kommt aber nur, wer eine externe IP-Adresse hat oder Cloud NAT nutzt.

### Schritte

```bash
./create-vpc.sh                      # nur das Netz
./create-vpc.sh --with-vm            # zusätzlich zwei Test-VMs
./create-vpc.sh --with-vm --with-nat # zusätzlich Cloud Router und Cloud NAT (kostet!)
```

Mit `--with-vm` entstehen zwei VMs: ein **Bastion-Host** im Subnetz `public` mit externer Adresse und eine **private VM** im Subnetz `app` ohne externe Adresse (`--no-address`). Die private VM ist nur über den Bastion-Host erreichbar (SSH-Sprung mit `-J`).

Ein Bastion-Host ist das klassische Muster für den Zugang zu privaten Subnetzen. Google Cloud bietet dafür den Identity-Aware Proxy (IAP): `gcloud compute ssh --tunnel-through-iap` erreicht VMs ohne externe Adresse, nur eine Firewall-Regel für den Adressbereich von IAP (35.235.240.0/20) ist nötig.

### Prüfen

```bash
./check-vpc.sh
```

Das Skript meldet sich am Bastion-Host an, springt von dort auf die private VM und prüft vier Erwartungen aus dem Netzentwurf:

| Prüfung | ohne `--with-nat` | mit `--with-nat` |
|---|---|---|
| Bastion-Host erreicht das Internet | ja | ja |
| private VM über den Bastion-Host erreichbar | ja | ja |
| private VM erreicht das Internet | nein | ja (über Cloud NAT) |
| private VM direkt von hier erreichbar | nein | nein |

Die private VM löst Namen auch ohne Cloud NAT auf – der Metadatenserver (169.254.169.254) beantwortet DNS-Anfragen in jeder VPC. Die Verbindung zur Website scheitert dann erst danach.

Von Hand:

```bash
ssh ubuntu@<bastion-ip>
ssh -J ubuntu@<bastion-ip> ubuntu@<private-ip>
gcloud compute networks subnets list --network pf-<owner>-vpc
gcloud compute firewall-rules list --filter 'network~pf-<owner>-vpc$'
```

Die Adressen stehen in der Ausgabe von `create-vpc.sh` und in `../.state/t04.env`. Wechselt die eigene IP-Adresse (anderes WLAN), lässt die Regel `allow-ssh` keine Verbindung mehr zu – dann `./destroy-vpc.sh` und neu anlegen.

### Aufräumen

```bash
./destroy-vpc.sh
```

### Fragen zum Weiterdenken

- Welche Vorteile hat eine globale VPC für eine Anwendung in mehreren Regionen?
- Warum sind Netzwerk-Tags (oder Service Accounts) als Ziel von Firewall-Regeln praktischer als Adressbereiche?
- Wozu dient Private Google Access, und warum braucht die Datenbank-Schicht trotzdem kein NAT?

## Teil 2: Diagnose

```bash
./diagnose.sh                          # www.openstreetmap.org
./diagnose.sh https://<eigene-url>     # z. B. der Dienst aus Termin 3
```

Das Skript zeigt nacheinander die DNS-Antwort mit TTL und Resolver, die Delegation ab der Root-Zone (`dig +trace`), Verbindungsaufbau und TLS-Handshake (`curl --verbose`), die Zeit bis zu jedem Schritt (`curl --write-out`) und die Zertifikatskette (`openssl s_client`). Blockiert das Netz DNS-Anfragen an andere Server als den eigenen Resolver (manche Firmen- und Hochschulnetze), bleibt der Abschnitt `dig +trace` leer.

## Teil 3: Gateway API und TLS lokal

**Kosten:** keine – alles läuft im Dev Container. Der Cluster `net` hat einen Node und braucht mit allen Pods rund 1,5 GB Arbeitsspeicher; läuft der Cluster `pf` aus Termin 3 noch, ihn bei Bedarf mit `k3d cluster stop pf` anhalten.

```bash
./gateway-up.sh      # beim ersten Mal 3–5 Minuten
curl --cacert ../.state/course-ca.crt --resolve placefinder.test:8443:127.0.0.1 \
  "https://placefinder.test:8443/places?q=Berlin"
./gateway-down.sh
```

`gateway-up.sh` baut die Demo aus Termin 4 nach und ist mehrfach aufrufbar:

1. Cluster `net` mit k3d; Port 8443 des Dev Containers führt auf Port 443 des Clusters.
2. `k8s/traefik-gw.yaml` schaltet den Gateway-API-Provider des Traefik ein, den k3s mitbringt; Traefik legt die GatewayClass `traefik` an.
3. PlaceFinder mit dem Manifest aus Termin 3 (`deploy/k8s/` im Repository `placefinder`); fehlt das Image, baut es `../t03-container/build-image.sh`.
4. cert-manager mit Helm, Gateway-API-Unterstützung über `k8s/cert-manager-values.yaml`.
5. Eine eigene Kurs-CA in `../.state/course-ca.crt` (30 Tage gültig, wird danach neu angelegt) als Secret für den ClusterIssuer `k8s/issuer.yaml`.
6. Gateway (`k8s/gateway.yaml`) und HTTPRoute (`k8s/route.yaml`); cert-manager legt das Zertifikat `pf-tls` von selbst an.
7. Eine Anfrage über HTTPS, geprüft gegen die Kurs-CA.

`--resolve` ersetzt den DNS-Eintrag für `placefinder.test` (die Endung `.test` ist für Tests reserviert), `--cacert` vertraut der Kurs-CA. Ohne `--cacert` bricht `curl` mit einem Zertifikatsfehler ab; `curl --verbose` zeigt Handshake, Zertifikat und Aussteller.

```bash
kubectl get gatewayclass,gateway,httproute
kubectl describe certificate pf-tls       # ausgestellt von course-ca, Laufzeit, Erneuerung
openssl x509 -in ../.state/course-ca.crt -noout -subject -enddate
```

**NetworkPolicies (Aufgabe 4):**

```bash
kubectl apply --filename k8s/networkpolicies.yaml
curl --cacert ../.state/course-ca.crt --resolve placefinder.test:8443:127.0.0.1 \
  "https://placefinder.test:8443/places?q=Berlin"          # geht weiter: über das Gateway
kubectl run test --rm --stdin --tty --image=busybox:1.37 -- \
  wget --timeout 3 --quiet --output-document - http://placefinder   # blockiert
kubectl delete --filename k8s/networkpolicies.yaml
```

`default-deny` verbietet allen Pods im Namespace `default` eingehenden Verkehr, `placefinder-from-gateway` erlaubt PlaceFinder Port 8000 aus dem Namespace `kube-system`, in dem Traefik läuft. k3s setzt NetworkPolicies mit einem eingebauten Controller durch.

**Typische Probleme**

- Keine GatewayClass `traefik` nach vier Minuten: `kubectl --namespace kube-system get pods` – läuft Traefik nach dem Neustart wieder?
- Zertifikat nicht `Ready`: `kubectl describe certificate pf-tls` und `kubectl --namespace cert-manager logs deployment/cert-manager`.
- `curl` erreicht nichts: Läuft der Befehl im Terminal des Dev Containers? Port 8443 gibt es nur dort.

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Netz | VPC, regional | Virtual Network, regional | VPC, global |
| Subnetz | eine Zone | alle Zonen der Region | regional |
| Reservierte Adressen je Subnetz | 5 | 5 | 4 |
| Firewall | Security Groups, Network ACLs | Network Security Groups | Firewall-Regeln mit Netzwerk-Tags |
| Ausgehend ohne öffentliche Adresse | NAT-Gateway | NAT-Gateway | Cloud NAT |
| Zugang ohne Bastion-Host | Session Manager | Azure Bastion | Identity-Aware Proxy (IAP) |
