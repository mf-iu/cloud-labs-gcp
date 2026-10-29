# 03 – Container-Dienst: Registry, Serverless Container, neue Versionen

Zwei Teile und ein Zusatz: In Termin 3 kommt das Image von PlaceFinder auf den Container-Dienst von Google Cloud. In Termin 5 rollt jeder seinen eigenen Stand der REST-API per Digest auf demselben Dienst aus, prüft ihn mit dem Smoke-Test und löscht den Dienst wieder. Das API-Gateway mit Rate Limit ist **Zusatz** – freiwillig und ohne Folgen für spätere Termine.

Was nicht vom Anbieter abhängt, steht in `cloud-labs-local`: das Image bauen und nach ghcr.io laden ([02-container](https://github.com/mf-iu/cloud-labs-local/tree/master/02-container)), Kubernetes lokal mit k3d ([03-kubernetes](https://github.com/mf-iu/cloud-labs-local/tree/master/03-kubernetes)), der Filter und die lokalen Prüfungen ([05-rest-api](https://github.com/mf-iu/cloud-labs-local/tree/master/05-rest-api)). Smoke-Test und Lasttest kommen aus `cloud-labs-local/tools`; die gleichnamigen Skripte hier rufen sie mit der Adresse des Dienstes auf.

| Skript | Aufgabe |
|---|---|
| `push-image.sh` | Repository in der Artifact Registry anlegen, Image von ghcr.io hineinkopieren |
| `deploy.sh`, `destroy.sh` | Cloud-Run-Dienst anlegen und auf `/health` warten; Dienst und Repository löschen |
| `update-service.sh` | Image `t05` in die Artifact Registry kopieren, per Digest als neue Revision ausrollen, Smoke-Test starten; ohne Dienst aus Termin 3 legt es ihn an |
| `smoke-test.sh` | Smoke-Test aus `cloud-labs-local/tools` gegen den Dienst; mit `--gateway` gegen das API-Gateway mit Schlüssel |
| `create-api-gateway.sh`, `destroy-api-gateway.sh` | API Gateway mit API-Key und Kontingent vor dem Dienst anlegen und wieder löschen (Beschreibung in `openapi2.yaml`) |
| `rate-limit-test.sh` | Lasttest aus `cloud-labs-local/tools` gegen das API-Gateway: viele Anfragen gleichzeitig, Antworten 200 und 429 |

## Teil 1: Registry und Cloud Run (Termin 3, Selbstlernphase)

**Ziel:** Das PlaceFinder-Image liegt in der Artifact Registry und läuft auf Cloud Run. Cloud Run startet Container für eingehende Anfragen, skaliert bis auf null und stellt eine HTTPS-Adresse mit Zertifikat bereit.

**Kosten:** Cloud Run: 2 Millionen Anfragen und ein Kontingent an vCPU- und GiB-Sekunden pro Monat kostenlos. Artifact Registry: 0,5 GB Speicher kostenlos – nicht mehr als ein, zwei Images aufbewahren.

### Voraussetzungen

- Docker im Dev Container
- Image `$PLACEFINDER_IMAGE:t03` auf ghcr.io: `/workspaces/cloud-labs-local/02-container/publish-image.sh`, danach das Paket auf GitHub öffentlich machen (*Packages* → *placefinder* → *Package settings* → *Change visibility*). Das Skript prüft, ob das geklappt hat.

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

## Teil 2: eigenen Stand ausrollen, prüfen, löschen (Termin 5)

**Ziel:** Der eigene Stand von PlaceFinder – der Tag `t05` mit einem zusätzlichen Filter – läuft als neue Revision des Cloud-Run-Dienstes aus Termin 3. Ein Smoke-Test prüft die HTTP-Eigenschaften aus Termin 5 gegen die Cloud. Als Zusatz steht Google API Gateway mit API-Key und Kontingent davor.

**Kosten:** Cloud Run wie in Termin 3, im Freikontingent. API Gateway: 2 Millionen Aufrufe im Monat kostenlos.

### Eigenen Stand bauen

Im Terminal des Dev Containers einen Zweig vom Tag `t05` der Musterlösung anlegen, den Filter ergänzen (Aufgabe auf der Übungsfolie von Termin 5) und das Image nach ghcr.io laden:

```bash
cd /workspaces/placefinder
git fetch upstream --tags                # tag t05 of the sample solution
git switch --create filter t05           # own branch from t05
# ... add the filter and its test ...
uv run pytest
../cloud-labs-local/02-container/publish-image.sh --tag t05
```

`publish-image.sh` baut den ausgecheckten Stand und lädt `placefinder:0.5.0` und `placefinder:t05` hoch; das Paket auf ghcr.io muss öffentlich sein. `upstream` einrichten: siehe [cloud-labs-local/00-setup](https://github.com/mf-iu/cloud-labs-local/tree/master/00-setup); Filter, Tests und Smoke-Test lokal: [cloud-labs-local/05-rest-api](https://github.com/mf-iu/cloud-labs-local/tree/master/05-rest-api). Ohne eigene Änderung lässt sich auch der Tag `t05` selbst ausrollen.

Der Dienst aus Teil 1 darf noch laufen. Wurde er gelöscht, legt `update-service.sh` ihn neu an.

### Ausrollen und prüfen

```bash
cd /workspaces/cloud-labs-gcp/03-container-service
./update-service.sh                      # a few minutes, ends with the smoke test
./smoke-test.sh                          # any time again; without URL: the service from t03
curl "<SERVICE_URL>/v1/places?min_population=1000000"   # the new filter
./smoke-test.sh http://localhost:8000    # the same checks against the local server
```

Die URL steht am Ende der Ausgabe von `update-service.sh` und in `../.state/t03.env` (`SERVICE_URL`). Den neuen Filter kennt der Smoke-Test nicht; ihn prüft `curl` von Hand.

**Digest statt Tag:** `update-service.sh` rollt `…/placefinder@sha256:…` aus, nicht `…:t05`. Ein Tag lässt sich später auf ein anderes Image setzen, der Digest benennt genau dieses eine. Cloud Run löst einen Tag zwar beim Deployment selbst in einen Digest auf; mit dem Digest im Befehl ist aber schon vorher klar, welches Image läuft.

**Revisionen:** Cloud Run legt bei jedem Deployment eine neue **Revision** an und leitet den Verkehr auf sie um, sobald sie bereit ist; `gcloud run deploy` wartet darauf. Mit `gcloud run deploy … --no-traffic` und `gcloud run services update-traffic … --to-revisions <revision>=10` ließe sich der Verkehr auch aufteilen (Canary). Der Dienst skaliert auf null; die erste Anfrage nach einer Pause dauert etwas länger.

**Smoke-Test:** Die Ausgabe zeigt je Prüfung `OK` oder `FAIL` mit dem erwarteten Wert, am Ende ein Beispiel für Problem Details. Geprüft werden Medientyp `application/geo+json`, Länge vor Breite, Umkreis und Bounding Box um Erfurt, der Link `next` im Header `Link` und im Body, `ETag` mit `304 Not Modified`, Fehler als `application/problem+json`, CORS für die Karte auf `http://localhost:5173` und die Header `Deprecation` und `Sunset` der Version 0.

**Karte mit den Daten aus der Cloud:** In PlaceFinder `python3 -m http.server 5173 --directory frontend` starten und `http://localhost:5173/?api=<SERVICE_URL>` öffnen. Die API erlaubt diese Herkunft über CORS (`CORS_ORIGINS`).

### Aufräumen – gehört zur Übung

```bash
./destroy.sh
../tools/find-leftovers.sh
```

Wer das API-Gateway (Zusatz) angelegt hat, löscht es vorher mit `./destroy-api-gateway.sh` – es zeigt auf den Dienst. Erst wenn `find-leftovers.sh` nichts mehr meldet, ist die Übung fertig.

### Typische Probleme

- `Cannot pull … without login`: Das Image fehlt auf ghcr.io oder ist privat – siehe „Eigenen Stand bauen“.
- Smoke-Test meldet Version 0.1.x und viele `FAIL`: Der Dienst läuft noch mit dem Stand von Termin 3. Image mit `--tag t05` bauen, dann `./update-service.sh`.
- `401` oder `403` über das Gateway direkt nach dem Anlegen: Key und Konfiguration brauchen einige Minuten, bis sie überall gelten; das Skript wartet darauf.
- `429` im Smoke-Test über das Gateway: kurz nach `rate-limit-test.sh` – eine Minute warten.

### Fragen zum Weiterdenken

- Welche Aufgaben übernimmt das API Gateway, die sonst in der Anwendung stünden?
- Warum ist es ein Vorteil, dass nur beschriebene Pfade durchgelassen werden – und wann ist es lästig?
- Wie würde man Cloud Run auf `--no-allow-unauthenticated` umstellen, sodass nur noch das Gateway den Dienst erreicht?
- Ein API-Key kennzeichnet eine Anwendung, keinen Menschen. Wann reicht das, und wann braucht es OAuth 2.0?

## Zusatz: API Gateway mit API-Key und Kontingent

```bash
./create-api-gateway.sh         # einige Minuten
./smoke-test.sh --gateway       # dieselben Prüfungen über das Gateway, mit API-Key
./rate-limit-test.sh            # 60 Anfragen, je 10 gleichzeitig: 200 und 429
./destroy-api-gateway.sh
```

Google API Gateway verlangt eine Beschreibung im Format **OpenAPI 2.0** (`openapi2.yaml`). Nur die dort beschriebenen Pfade gelangen zum Dienst; alles andere beantwortet das Gateway selbst mit 404. Die Erweiterung `x-google-backend` nennt das Ziel, `APPEND_PATH_TO_ADDRESS` hängt den Pfad an. Das Gateway ruft Cloud Run mit der Identität eines eigenen Service Accounts auf, der die Rolle *Cloud Run Invoker* erhält – so ließe sich der Dienst selbst auch privat schalten. API Gateway gibt es nicht in jeder Region; das Skript nutzt `europe-west1` (Belgien), weil `europe-west3` (Frankfurt) fehlt.

- **API-Key:** `securityDefinitions` verlangt einen Schlüssel im Header `x-api-key`; ohne ihn antwortet das Gateway mit 401. Das Skript aktiviert den eigenen Dienst (*Managed Service*) der API im Projekt, legt einen API-Key an, der nur für diesen Dienst gilt, und speichert ihn in `../.state/t05.env`; `--gateway` sendet ihn mit.
- **Kontingent:** `x-google-management` definiert eine Metrik `requests` und ein Limit von 30 Anfragen pro Minute je Projekt des API-Keys; `x-google-quota` gibt an, wie viel jede Operation davon verbraucht. Darüber antwortet das Gateway mit `429 Too Many Requests`. Das Kontingent wird zentral gezählt und mit etwas Verzögerung durchgesetzt; einige Anfragen über dem Limit sind normal.
- **Änderungen:** Eine API-Konfiguration ist unveränderlich. Nach einer Änderung an `openapi2.yaml` legt `./create-api-gateway.sh` eine neue an und stellt das Gateway darauf um.

Das Gateway braucht den laufenden Dienst: erst `./update-service.sh`, am Ende `./destroy-api-gateway.sh` und `./destroy.sh`.

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Registry | Amazon ECR | Azure Container Registry (hier: ghcr.io) | Artifact Registry |
| Serverless Container | ECS Express Mode auf Fargate | Azure Container Apps | Cloud Run |
| Skalierung auf null | nein | ja | ja |
| Neue Version | Canary-Deployment mit automatischem Rollback | neue Revision | neue Revision, Traffic Splitting |
| API-Gateway | API Gateway (HTTP API) | API Management (Consumption) | API Gateway |
| Rate Limit | Throttling je Stage oder Route, für alle Clients zusammen | Richtlinie `rate-limit` je Abonnement | Kontingent je Projekt des API-Keys |
| Schlüssel | API-Keys nur bei REST APIs | Abonnementschlüssel im Header `Ocp-Apim-Subscription-Key` | API-Key, hier im Header `x-api-key` |
