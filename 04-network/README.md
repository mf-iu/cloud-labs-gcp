# 04 – Netze: VPC in Google Cloud

Die Übung von Termin 4 läuft im Termin: Nach dem Entwurf auf Papier wird das Netz als VPC in Google Cloud angelegt, mit dem Entwurf verglichen und wieder gelöscht (ca. 45 Minuten). Alles Weitere ist **Zusatz** – freiwillig und ohne Folgen für spätere Termine: Test-VMs und Cloud NAT. Diagnose einer HTTPS-Anfrage und die Demo mit Gateway API und cert-manager im lokalen Cluster stehen in [cloud-labs-local/04-cluster-network](https://github.com/mf-iu/cloud-labs-local/tree/master/04-cluster-network).

| Skript | Aufgabe |
|---|---|
| `create-vpc.sh` | VPC mit Subnetzen und Firewall-Regeln anlegen; optional Test-VMs und Cloud NAT |
| `check-vpc.sh` | Netz mit dem Entwurf vergleichen; mit Test-VMs auch: Was ist von wo erreichbar? |
| `destroy-vpc.sh` | alles wieder löschen |

## Im Termin: Netz anlegen, prüfen, löschen

**Ziel:** drei regionale Subnetze für öffentliche Dienste, Anwendung und Datenbank und Firewall-Regeln, die über Netzwerk-Tags festlegen, wer wen erreichen darf.

**Kosten:** VPC, Subnetze und Firewall-Regeln sind kostenlos; ohne die Optionen `--with-vm` und `--with-nat` entsteht nichts, was Geld kostet.

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

### Anlegen

```bash
./create-vpc.sh
```

Das Skript läuft ein bis zwei Minuten und zeigt am Ende eine Übersicht der Subnetze.

### Prüfen

```bash
./check-vpc.sh
```

Das Skript vergleicht das angelegte Netz mit dem Entwurf und markiert Abweichungen mit `UNEXPECTED`:

| Prüfung | Erwartung |
|---|---|
| Adressbereich je Subnetz | `public` = `10.20.0.0/24`, `app` = `10.20.10.0/24`, `db` = `10.20.20.0/24` |
| Internetzugang von `app` und `db` | keiner – VMs ohne externe Adresse und ohne Cloud NAT (mit `--with-nat`: `app` über Cloud NAT) |
| Private Google Access für `db` | eingeschaltet |
| Firewall-Regeln je Netzwerk-Tag | `lb`: tcp:443 von `0.0.0.0/0`, `app`: tcp:8000 von Tag `lb`, `db`: tcp:5432 von Tag `app` |

Die Regeln für SSH (mit `--with-vm`) prüft das Skript nicht; sie gehören nicht zum Entwurf.

Zum Ausprobieren: in der Konsole des Anbieters eine Regel ändern, etwa die Datenbank aus dem ganzen Internet erlauben, und `./check-vpc.sh` erneut aufrufen. Danach die Änderung zurücknehmen.

Von Hand:

```bash
gcloud compute networks subnets list --network pf-<owner>-vpc
gcloud compute firewall-rules list --filter 'network~pf-<owner>-vpc$'
```

### Aufräumen – gehört zur Übung

```bash
./destroy-vpc.sh
../tools/find-leftovers.sh
```

Erst wenn beide Befehle durchgelaufen sind, ist die Übung fertig.

### Fragen zum Weiterdenken

- Welche Vorteile hat eine globale VPC für eine Anwendung in mehreren Regionen?
- Warum sind Netzwerk-Tags (oder Service Accounts) als Ziel von Firewall-Regeln praktischer als Adressbereiche?
- Wozu dient Private Google Access, und warum braucht die Datenbank-Schicht trotzdem kein NAT?

## Zusatz: Test-VMs und Cloud NAT

**Kosten:** Die beiden Test-VMs (`e2-micro` in `GCP_ZONE`) kosten in Frankfurt zusammen wenige Cent pro Stunde. **Cloud NAT kostet je VM 0,0014 USD pro Stunde (höchstens 0,044 USD), dazu 0,005 USD pro Stunde für seine IP-Adresse und 0,045 USD je GB** – für die eine private VM nur wenige Cent pro Tag. Am selben Tag wieder löschen.

Die Optionen gelten nur beim Anlegen; ein bestehendes Netz erst mit `./destroy-vpc.sh` löschen.

```bash
./create-vpc.sh --with-vm            # zusätzlich zwei Test-VMs
./create-vpc.sh --with-vm --with-nat # zusätzlich Cloud Router und Cloud NAT (kostet!)
./check-vpc.sh
```

Mit `--with-vm` entstehen zwei VMs: ein **Bastion-Host** im Subnetz `public` mit externer Adresse und eine **private VM** im Subnetz `app` ohne externe Adresse (`--no-address`). Die private VM ist nur über den Bastion-Host erreichbar (SSH-Sprung mit `-J`).

Ein Bastion-Host ist das klassische Muster für den Zugang zu privaten Subnetzen. Google Cloud bietet dafür den Identity-Aware Proxy (IAP): `gcloud compute ssh --tunnel-through-iap` erreicht VMs ohne externe Adresse, nur eine Firewall-Regel für den Adressbereich von IAP (35.235.240.0/20) ist nötig.

Mit Test-VMs meldet sich `check-vpc.sh` zusätzlich am Bastion-Host an, springt von dort auf die private VM und prüft vier Erwartungen an die Erreichbarkeit:

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
```

Die Adressen stehen in der Ausgabe von `create-vpc.sh` und in `../.state/t04.env`. Wechselt die eigene IP-Adresse (anderes WLAN), lässt die Regel `allow-ssh` keine Verbindung mehr zu – dann `./destroy-vpc.sh` und neu anlegen.

Danach aufräumen wie oben: `./destroy-vpc.sh`.

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Netz | VPC, regional | Virtual Network, regional | VPC, global |
| Subnetz | eine Zone | alle Zonen der Region | regional |
| Reservierte Adressen je Subnetz | 5 | 5 | 4 |
| Firewall | Security Groups, Network ACLs | Network Security Groups | Firewall-Regeln mit Netzwerk-Tags |
| Ausgehend ohne öffentliche Adresse | NAT-Gateway | NAT-Gateway | Cloud NAT |
| Zugang ohne Bastion-Host | Session Manager | Azure Bastion | Identity-Aware Proxy (IAP) |
