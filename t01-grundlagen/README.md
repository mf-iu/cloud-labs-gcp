# T01 – Konto absichern, Projekt, CLI und Budget-Alarm

**Ziel:** Ein Google-Cloud-Konto mit Testguthaben und Bestätigung in zwei Schritten, ein eigenes Projekt für den Kurs, eine funktionierende `gcloud`-CLI im Dev Container und ein Budget-Alarm, der vor unerwarteten Kosten warnt.

**Kosten:** keine.

## 1. Konto anlegen (Browser)

1. Mit einem Google-Konto auf <https://cloud.google.com/free> die kostenlose Testversion starten (300 USD Guthaben für 90 Tage). Die Kreditkarte dient nur der Identitätsprüfung; ohne Umstellung auf ein kostenpflichtiges Konto wird nichts berechnet.
2. Für das Google-Konto die **Bestätigung in zwei Schritten** einschalten (<https://myaccount.google.com/security>), z. B. mit einem Passkey oder der Authenticator-App.
3. In der Konsole unter *Billing* prüfen, dass ein offenes Abrechnungskonto mit dem Testguthaben besteht.

Bei Google Cloud gehört jede Ressource zu einem **Projekt**. Rechte vergibt Cloud IAM auf Organisation, Ordner oder Projekt; als Inhaber des Kontos ist man Owner der eigenen Projekte.

## 2. CLI anmelden und Projekt anlegen (Dev Container)

Im Terminal des Dev Containers (siehe [README](../README.md#arbeitsumgebung-dev-container)):

```bash
cp ../config.example.env ../config.env   # OWNER, BUDGET_AMOUNT usw. eintragen
gcloud auth login --no-launch-browser
gcloud auth application-default login --no-launch-browser
./create-project.sh
./check-cli.sh
```

Die beiden Anmeldungen zeigen je eine URL; die Anmeldung erfolgt im Browser auf dem Notebook, danach den Code in das Terminal kopieren. Die erste Anmeldung gilt für `gcloud`, die zweite (Application Default Credentials) für Programme wie OpenTofu und die Python-Bibliotheken.

`create-project.sh` legt das Projekt `pf-<owner>-<zufall>` an (Projekt-IDs sind weltweit eindeutig), verknüpft es mit dem Abrechnungskonto und merkt sich die ID in `../.state/gcp_project`. Wer ein vorhandenes Projekt nutzen will, trägt es in `config.env` als `GCP_PROJECT` ein.

## 3. Budget-Alarm

```bash
./create-budget.sh      # Monatsbudget BUDGET_AMOUNT aus config.env, Standard 10
```

Google schickt eine E-Mail an die Abrechnungsadministratoren (also an das eigene Konto), wenn die tatsächlichen Kosten 50 % und 80 % des Budgets überschreiten oder die Prognose 100 % erreicht. Der Betrag gilt in der Währung des Abrechnungskontos. Das Budget rechnet ohne Gutschriften: Während der Testphase bezahlt das Guthaben alles, ein Budget nach Abzug der Gutschriften bliebe immer bei 0 und würde nie warnen. Andere Empfänger lassen sich über Benachrichtigungskanäle von Cloud Monitoring ergänzen.

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
