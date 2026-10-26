# T05 – Neue API-Version ausrollen, testen und absichern

Die Übung von Termin 5 läuft im Termin: einen Filter mit Test ergänzen, den eigenen Stand per Digest auf dem Dienst aus Termin 3 ausrollen, mit dem Smoke-Test prüfen und den Dienst wieder löschen. Das API-Gateway mit Rate Limit ist **Zusatz** – freiwillig und ohne Folgen für spätere Termine.

**Ziel:** Der eigene Stand von PlaceFinder – der Tag `t05` mit einem zusätzlichen Filter – läuft als neue Revision des Cloud-Run-Dienstes aus Termin 3. Ein Smoke-Test prüft die HTTP-Eigenschaften aus Termin 5 gegen die Cloud. Als Zusatz steht Google API Gateway mit API-Key und Kontingent davor.

| Skript | Aufgabe |
|---|---|
| `update-service.sh` | Image `t05` in die Artifact Registry kopieren, per Digest als neue Revision ausrollen, Smoke-Test starten; ohne Dienst aus Termin 3 legt es ihn an |
| `smoke-test.sh` | REST-API prüfen: Suche, Filter, Paginierung, ETag und 304, Problem Details, CORS, veraltete Version 0 – gegen jede URL, auch lokal |
| `create-api-gateway.sh`, `destroy-api-gateway.sh` | API Gateway mit API-Key und Kontingent vor dem Dienst anlegen und wieder löschen (Beschreibung in `openapi2.yaml`) |
| `rate-limit-test.sh` | viele Anfragen gleichzeitig senden und die Antworten zählen: 200 und 429 |

**Kosten:** Cloud Run wie in Termin 3, im Freikontingent. API Gateway: 2 Millionen Aufrufe im Monat kostenlos.

## Im Termin: eigenen Stand ausrollen, prüfen, löschen

### Eigenen Stand bauen

Im Terminal des Dev Containers einen Zweig vom Tag `t05` der Musterlösung anlegen, den Filter ergänzen (Aufgabe auf der Übungsfolie von Termin 5) und das Image nach ghcr.io laden:

```bash
cd /workspaces/placefinder
git fetch upstream --tags                # tag t05 of the sample solution
git switch --create filter t05           # own branch from t05
# ... add the filter and its test ...
uv run pytest
../cloud-labs-gcp/t03-container/build-image.sh --push --tag t05
```

`build-image.sh` baut den ausgecheckten Stand und lädt `placefinder:0.5.0` und `placefinder:t05` hoch; das Paket auf ghcr.io muss öffentlich sein. `upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose). Ohne eigene Änderung lässt sich auch der Tag `t05` selbst ausrollen.

Der Dienst aus [t03-container](../t03-container/README.md) (Teil 2) darf noch laufen. Wurde er gelöscht, legt `update-service.sh` ihn neu an.

### Ausrollen und prüfen

```bash
cd /workspaces/cloud-labs-gcp/t05-rest-api
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
../t03-container/destroy.sh
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

Das Gateway braucht den laufenden Dienst: erst `./update-service.sh`, am Ende `./destroy-api-gateway.sh` und `../t03-container/destroy.sh`.

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Neue Version | Canary-Deployment mit automatischem Rollback | neue Revision | neue Revision, Traffic Splitting |
| API-Gateway | API Gateway (HTTP API) | API Management (Consumption) | API Gateway |
| Rate Limit | Throttling je Stage oder Route, für alle Clients zusammen | Richtlinie `rate-limit` je Abonnement | Kontingent je Projekt des API-Keys |
| Schlüssel | API-Keys nur bei REST APIs | Abonnementschlüssel im Header `Ocp-Apim-Subscription-Key` | API-Key, hier im Header `x-api-key` |
