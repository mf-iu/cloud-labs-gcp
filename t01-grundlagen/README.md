# T01 – Konto absichern, Projekt, CLI und Budget-Alarm

**Ziel:** Ein Google-Cloud-Konto mit Testguthaben und Bestätigung in zwei Schritten, ein eigenes Projekt für den Kurs, eine funktionierende `gcloud`-CLI im Dev Container und ein Budget-Alarm, der vor unerwarteten Kosten warnt.

**Kosten:** keine.

## 1. Konto anlegen (Browser)

Zeitbedarf ca. 15 Minuten. Bereithalten: ein Google-Konto mit E-Mail-Adresse (Gmail oder eine andere Adresse; Konten nur mit Telefonnummer gehen nicht), eine Kredit- oder Debitkarte, ein Mobiltelefon und die Authenticator-App oder einen Passkey. Die Testversion gibt es nur für Konten, die noch nie zahlende Kunden von Google Cloud, Google Maps Platform oder Firebase waren und die Testversion noch nicht genutzt haben.

### 1.1 Google-Konto absichern

Das Google-Konto wird Inhaber der Projekte und Administrator des Abrechnungskontos; wer es kennt, kann über das Guthaben verfügen. Deshalb zuerst auf <https://myaccount.google.com/security> die **Bestätigung in zwei Schritten** einschalten, z. B. mit einem Passkey oder der Authenticator-App, und Backup-Codes sicher ablegen. Google verlangt die Bestätigung in zwei Schritten ohnehin für die Anmeldung an der Cloud-Konsole.

### 1.2 Testversion starten

1. <https://cloud.google.com/free> öffnen, *Kostenlos starten* bzw. *Get started for free* wählen und mit dem Google-Konto anmelden.
2. Als Land **Deutschland** wählen und die Nutzungsbedingungen akzeptieren.
3. Kontotyp, Name und Adresse eintragen und die Karte angeben. Sie dient der Identitätsprüfung; die Bank zeigt eventuell eine Autorisierung von bis zu 1 USD, die nach 1–14 Werktagen verfällt. Berechnet wird nichts.
4. Danach öffnet sich die Konsole <https://console.cloud.google.com> mit dem automatisch angelegten Projekt „My First Project“.
5. Prüfen: *Abrechnung* (*Billing*) zeigt ein offenes Abrechnungskonto; unter *Gutschriften* (*Credits*) stehen das Restguthaben und das Ablaufdatum.

### 1.3 Was die Testversion bedeutet

- **Guthaben:** 300 USD für **90 Tage** – genug für eine Kurshälfte.
- **Keine Kosten:** Die Testversion geht nicht von selbst in ein kostenpflichtiges Konto über. Ist das Guthaben verbraucht oder sind 90 Tage um, werden alle Projekte und Ressourcen angehalten. 30 Tage lang lässt sich das Konto noch durch ein Upgrade wiederherstellen, danach löscht Google die Ressourcen.
- **Nicht auf ein kostenpflichtiges Konto umstellen** (*Aktivieren* bzw. *Activate* im Hinweis oben in der Konsole). Das beendet die Testversion; danach wird alles berechnet, was über Guthaben und kostenlose Kontingente hinausgeht.
- **Einschränkungen der Testversion:** keine GPUs, keine VMs mit Windows Server, keine Erhöhung von Kontingenten, kein Cloud Marketplace; Krypto-Mining ist verboten. Für den Kurs spielt das keine Rolle.
- **Dauerhaft kostenlos** (Free Tier, auch nach der Testversion): u. a. eine e2-micro-VM in `us-west1`, `us-central1` oder `us-east1`, 5 GB Cloud Storage in US-Regionen und 2 Millionen Anfragen pro Monat bei Cloud Run.

Bei Google Cloud gehört jede Ressource zu einem **Projekt**. Rechte vergibt Cloud IAM auf Organisation, Ordner oder Projekt; als Inhaber des Kontos ist man Owner der eigenen Projekte. Für den Kurs legt `create-project.sh` in Abschnitt 2 ein eigenes Projekt an; „My First Project“ bleibt ungenutzt, wird aber vom Budget-Alarm mit überwacht.

## 2. CLI anmelden und Projekt anlegen (Dev Container)

Im Terminal des Dev Containers (siehe [README](../README.md#arbeitsumgebung-dev-container)):

```bash
cd /workspaces/cloud-labs-gcp/t01-grundlagen   # Ordner dieser Übung
cp -i ../config.example.env ../config.env      # OWNER, BUDGET_AMOUNT usw. eintragen
gcloud auth login --no-launch-browser
gcloud auth application-default login --no-launch-browser
./create-project.sh
./check-cli.sh
```

`cp -i` fragt nach, falls `config.env` schon existiert (z. B. aus der Einrichtung im [README](../README.md#einrichtung)); dann mit `n` antworten und die vorhandene Datei behalten.

**`config.env` ausfüllen:** Die Datei enthält die persönlichen Einstellungen, die alle Skripte des Repositorys beim Start einlesen. Öffnen mit `code ../config.env`. Sie ist ein Shell-Skript: `NAME=wert` ohne Leerzeichen um das `=`, Werte mit Leerzeichen oder `$` in Anführungszeichen, Kommentare nach `#`. Die Datei steht in `.gitignore` und gelangt nie ins Repository. Änderungen gelten ab dem nächsten Skriptaufruf.

| Variable | Eintragen | Wofür |
|---|---|---|
| `PREFIX` | `pf` lassen | Anfang aller Ressourcennamen |
| `OWNER` | **eigene Initialen**, 2–4 Kleinbuchstaben, z. B. `mf` | Ressourcennamen wie `pf-mf-t02-vm` und die Projekt-ID `pf-mf-<zufall>`. Erlaubt sind nur Kleinbuchstaben, da Projekt-IDs keine Großbuchstaben, Umlaute oder Sonderzeichen enthalten dürfen. Später nicht mehr ändern, sonst finden die Skripte ihre Ressourcen nicht wieder. |
| `BUDGET_AMOUNT` | `10` lassen oder anpassen | Monatsbetrag des Budget-Alarms (Abschnitt 3) in der Währung des Abrechnungskontos. Eine E-Mail-Adresse ist nicht nötig: Google benachrichtigt die Abrechnungsadministratoren, also das eigene Konto. |
| `GCP_PROJECT` | **leer lassen** | `create-project.sh` legt das Projekt an und merkt sich die ID in `.state/gcp_project`. Nur eintragen, wer ein vorhandenes Projekt verwenden will. |
| `GCP_BILLING_ACCOUNT` | leer lassen | Ohne Angabe nimmt `create-project.sh` das erste offene Abrechnungskonto, also das der Testversion. Bei mehreren Abrechnungskonten die ID eintragen (`gcloud billing accounts list`). |
| `GCP_REGION`, `GCP_ZONE` | `europe-west3`, `europe-west3-a` lassen | Frankfurt; Standardort der Ressourcen |
| `GCP_FREE_ZONE` | `us-central1-a` lassen | Zone für die VM in Termin 2: Die dauerhaft kostenlose e2-micro-VM gibt es nur in `us-west1`, `us-central1` und `us-east1`. |
| `SSH_PUBLIC_KEY` | Pfad lassen | öffentlicher SSH-Schlüssel für die VMs (Termin 2 und 4), im Container `/home/vscode/.ssh/id_ed25519.pub`. Anlegen in WSL, siehe unten |
| `GITHUB_USER` | **eigener GitHub-Benutzername** | daraus ergeben sich die beiden folgenden Werte |
| `PLACEFINDER_REPO`, `PLACEFINDER_IMAGE` | nicht ändern | URL des eigenen PlaceFinder-Forks (Termin 2) und Name der Container-Images auf ghcr.io (ab Termin 3) |

Für Termin 1 genügen `OWNER` und `GITHUB_USER`; alle anderen Werte passen so, wie sie sind.

### SSH-Schlüssel für die VMs

Ab Termin 2 melden sich die Skripte per SSH an den VMs an. Den Schlüssel am besten gleich jetzt anlegen – **im Ubuntu-Terminal von WSL, nicht im Terminal des Containers.**

Warum: Der Ordner `~/.ssh` gehört zu WSL. Der Dev Container bindet ihn nur ein, damit die Schlüssel einen Neubau des Containers überstehen; im Container scheitert `ssh-keygen` daran. In WSL gehört der Ordner dem eigenen Benutzer, dort funktioniert es.

1. Das Ubuntu-Terminal öffnen: im Startmenü von Windows *Ubuntu* bzw. *Ubuntu 24.04* oder ein neues Ubuntu-Fenster im Windows-Terminal. Die Eingabeaufforderung zeigt `<benutzer>@<rechner>:~$`, nicht `vscode ➜ /workspaces/…`.
2. Den Schlüssel anlegen:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ```

   Die Passphrase darf leer bleiben (zweimal Enter). Gibt es den Schlüssel schon, fragt `ssh-keygen`, ob er überschrieben werden soll – dann mit `n` antworten und den vorhandenen verwenden.
3. Zurück im Container: Der Schlüssel liegt dort sofort unter `/home/vscode/.ssh/id_ed25519`, ein Neustart ist nicht nötig. Prüfen mit `ls ~/.ssh` im Terminal des Containers. `SSH_PUBLIC_KEY` in `config.env` zeigt bereits auf `~/.ssh/id_ed25519.pub`.

## 3. Budget-Alarm

```bash
./create-budget.sh      # Monatsbudget BUDGET_AMOUNT aus config.env, Standard 10
```

Google schickt eine E-Mail an die Abrechnungsadministratoren (also an das eigene Konto), wenn die tatsächlichen Kosten 50 % und 80 % des Budgets überschreiten oder die Prognose 100 % erreicht. Der Betrag gilt in der Währung des Abrechnungskontos. Das Budget überwacht das ganze Abrechnungskonto, also auch Kosten in anderen Projekten wie dem automatisch angelegten „My First Project“. Es rechnet ohne Gutschriften: Während der Testphase bezahlt das Guthaben alles, ein Budget nach Abzug der Gutschriften bliebe immer bei 0 und würde nie warnen. Andere Empfänger lassen sich über Benachrichtigungskanäle von Cloud Monitoring ergänzen.

Kontrolle in der Konsole: *Billing* → *Budgets & alerts*. Ein zweiter Aufruf ändert nichts; zum Ändern erst `./delete-budget.sh`, dann wieder `./create-budget.sh`. Endgültig löschen erst am Kursende.

## Fragen zum Weiterdenken

- Warum ist ein Budget-Alarm keine Kostenbremse? Wie ließe sich mit Pub/Sub und einer Function die Abrechnung bei Überschreitung abschalten?
- Welche Vorteile hat ein eigenes Projekt pro Kurs oder Anwendung?
- Was passiert nach 90 Tagen mit Konto und Projekt?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Anmeldung der CLI | `aws login` | `az login` | `gcloud auth login` |
| Budget | AWS Budgets | Cost Management Budgets | Cloud Billing Budgets |
| Gruppierung | Konto, Tags | Abonnement, Ressourcengruppe | Projekt, Labels |
