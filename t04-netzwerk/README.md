# T04 – VPC mit Subnetzen und Firewall-Regeln

**Ziel:** Der Netzentwurf aus der Übung von Termin 4 wird als VPC in Google Cloud angelegt: drei regionale Subnetze für öffentliche Dienste, Anwendung und Datenbank und Firewall-Regeln, die über Netzwerk-Tags festlegen, wer wen erreichen darf.

**Kosten:** VPC, Subnetze und Firewall-Regeln sind kostenlos. Die optionale Test-VM kostet in Frankfurt wenige Cent pro Stunde. Das optionale **Cloud NAT kostet ca. 0,045 USD pro Stunde plus Datenmenge** – am selben Tag wieder löschen.

## Aufbau

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
| allow-ssh (nur mit `--with-vm`) | 22 von der eigenen IP-Adresse | `ssh` |

Besonderheiten von Google Cloud: Die VPC ist **global**, die Subnetze sind regional und reichen über alle Zonen. „Öffentlich“ ist nicht das Subnetz, sondern eine VM mit externer IP-Adresse. Ohne eigene Regeln verbietet eine VPC jeden eingehenden und erlaubt jeden ausgehenden Verkehr; ausgehend ins Internet kommt aber nur, wer eine externe IP-Adresse hat oder Cloud NAT nutzt.

## Schritte

```bash
./create-vpc.sh                      # nur das Netz
./create-vpc.sh --with-vm            # zusätzlich Test-VM im Subnetz "public"
./create-vpc.sh --with-vm --with-nat # zusätzlich Cloud Router und Cloud NAT (kostet!)
```

## Prüfen

```bash
gcloud compute networks subnets list --network pf-<owner>-vpc
gcloud compute firewall-rules list --filter 'network~pf-<owner>-vpc$'
ssh ubuntu@<ip-der-test-vm>          # mit --with-vm
./diagnose.sh www.openstreetmap.org
```

`diagnose.sh` zeigt nacheinander DNS-Antworten, die Delegation ab der Root-Zone (`dig +trace`), Verbindungsaufbau und TLS-Handshake (`curl --verbose`) und die Zertifikatskette (`openssl s_client`).

## Aufräumen

```bash
./destroy-vpc.sh
```

## Fragen zum Weiterdenken

- Welche Vorteile hat eine globale VPC für eine Anwendung in mehreren Regionen?
- Warum sind Netzwerk-Tags (oder Service Accounts) als Ziel von Firewall-Regeln praktischer als Adressbereiche?
- Wozu dient Private Google Access, und warum braucht die Datenbank-Schicht trotzdem kein NAT?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Netz | VPC, regional | Virtual Network, regional | VPC, global |
| Subnetz | eine Zone | alle Zonen der Region | regional |
| Reservierte Adressen je Subnetz | 5 | 5 | 4 |
| Firewall | Security Groups, Network ACLs | Network Security Groups | Firewall-Regeln mit Netzwerk-Tags |
