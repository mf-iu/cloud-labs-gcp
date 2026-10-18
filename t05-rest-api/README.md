# T05 – Neue API-Version ausrollen, testen und absichern

**Ziel:** Der Stand `t05` von PlaceFinder – die REST-API v1 mit GeoJSON, Paginierung, ETags und Fehlern nach RFC 9457 – läuft als neue Revision des Cloud-Run-Dienstes aus Termin 3. Ein Smoke-Test prüft die HTTP-Eigenschaften aus Termin 5 gegen die Cloud. Optional steht Google API Gateway mit API-Key und Kontingent davor.

| Skript | Aufgabe |
|---|---|
| `update-service.sh` | Image `t05` in die Artifact Registry kopieren, per Digest als neue Revision ausrollen, Smoke-Test starten; ohne Dienst aus Termin 3 legt es ihn an |
| `smoke-test.sh` | REST-API prüfen: Suche, Filter, Paginierung, ETag und 304, Problem Details, CORS, veraltete Version 0 – gegen jede URL, auch lokal |
| `create-api-gateway.sh`, `destroy-api-gateway.sh` | API Gateway mit API-Key und Kontingent vor dem Dienst anlegen und wieder löschen (Beschreibung in `openapi2.yaml`) |
| `rate-limit-test.sh` | viele Anfragen gleichzeitig senden und die Antworten zählen: 200 und 429 |

**Kosten:** Cloud Run wie in Termin 3, im Freikontingent. API Gateway: 2 Millionen Aufrufe im Monat kostenlos.

## Voraussetzungen

- Image `$PLACEFINDER_IMAGE:t05` auf ghcr.io, öffentlich. Im Terminal des Dev Containers:
  ```bash
  cd /workspaces/placefinder
  git fetch upstream --tags                # Tag t05 der Musterlösung holen
  git switch --detach t05                  # oder den eigenen Stand verwenden
  ../cloud-labs-gcp/t03-container/build-image.sh --push --tag t05
  git switch master
  ```
  `build-image.sh` lädt `placefinder:0.5.0` und `placefinder:t05` hoch; `upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose).
- Der Dienst aus [t03-container](../t03-container/README.md) (Teil 2) darf noch laufen. Wurde er gelöscht, legt `update-service.sh` ihn neu an.

## Schritte

```bash
cd /workspaces/cloud-labs-gcp/t05-rest-api
./update-service.sh                      # wenige Minuten, endet mit dem Smoke-Test
./smoke-test.sh                          # jederzeit wieder; ohne URL: der Dienst aus Termin 3
./smoke-test.sh http://localhost:8000    # dieselben Prüfungen gegen den lokalen Server
```

**Digest statt Tag:** `update-service.sh` rollt `…/placefinder@sha256:…` aus, nicht `…:t05`. Ein Tag lässt sich später auf ein anderes Image setzen, der Digest benennt genau dieses eine. Cloud Run löst einen Tag zwar beim Deployment selbst in einen Digest auf; mit dem Digest im Befehl ist aber schon vorher klar, welches Image läuft.

**Revisionen:** Cloud Run legt bei jedem Deployment eine neue **Revision** an und leitet den Verkehr auf sie um, sobald sie bereit ist; `gcloud run deploy` wartet darauf. Mit `gcloud run deploy … --no-traffic` und `gcloud run services update-traffic … --to-revisions <revision>=10` ließe sich der Verkehr auch aufteilen (Canary). Der Dienst skaliert auf null; die erste Anfrage nach einer Pause dauert etwas länger.

**Smoke-Test:** Die Ausgabe zeigt je Prüfung `OK` oder `FAIL` mit dem erwarteten Wert, am Ende ein Beispiel für Problem Details. Geprüft werden Medientyp `application/geo+json`, Länge vor Breite, Umkreis und Bounding Box um Erfurt, der Link `next` im Header `Link` und im Body, `ETag` mit `304 Not Modified`, Fehler als `application/problem+json`, CORS für die Karte auf `http://localhost:5173` und die Header `Deprecation` und `Sunset` der Version 0.

**Karte mit den Daten aus der Cloud:** In PlaceFinder `python3 -m http.server 5173 --directory frontend` starten und `http://localhost:5173/?api=<SERVICE_URL>` öffnen. Die API erlaubt diese Herkunft über CORS (`CORS_ORIGINS`).

### Optional: API Gateway mit API-Key und Kontingent

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

## Typische Probleme

- `Cannot pull … without login`: Das Image fehlt auf ghcr.io oder ist privat – siehe Voraussetzungen.
- Smoke-Test meldet Version 0.1.x und viele `FAIL`: Der Dienst läuft noch mit dem Stand von Termin 3. Image mit `--tag t05` bauen, dann `./update-service.sh`.
- `401` oder `403` über das Gateway direkt nach dem Anlegen: Key und Konfiguration brauchen einige Minuten, bis sie überall gelten; das Skript wartet darauf.
- `429` im Smoke-Test über das Gateway: kurz nach `rate-limit-test.sh` – eine Minute warten.

## Aufräumen

```bash
./destroy-api-gateway.sh       # falls angelegt
../t03-container/destroy.sh
```

## Fragen zum Weiterdenken

- Welche Aufgaben übernimmt das API Gateway, die sonst in der Anwendung stünden?
- Warum ist es ein Vorteil, dass nur beschriebene Pfade durchgelassen werden – und wann ist es lästig?
- Wie würde man Cloud Run auf `--no-allow-unauthenticated` umstellen, sodass nur noch das Gateway den Dienst erreicht?
- Ein API-Key kennzeichnet eine Anwendung, keinen Menschen. Wann reicht das, und wann braucht es OAuth 2.0?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Neue Version | Canary-Deployment mit automatischem Rollback | neue Revision | neue Revision, Traffic Splitting |
| API-Gateway | API Gateway (HTTP API) | API Management (Consumption) | API Gateway |
| Rate Limit | Throttling je Stage oder Route, für alle Clients zusammen | Richtlinie `rate-limit` je Abonnement | Kontingent je Projekt des API-Keys |
| Schlüssel | API-Keys nur bei REST APIs | Abonnementschlüssel im Header `Ocp-Apim-Subscription-Key` | API-Key, hier im Header `x-api-key` |
