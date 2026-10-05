# T05 – API-Version ausrollen, testen und absichern

**Ziel:** Die REST-API aus Termin 5 (Stand `t05`: GeoJSON, Paginierung, ETags, Fehler nach RFC 9457) läuft als neue Revision des Cloud-Run-Dienstes aus Termin 3. Ein Smoke-Test prüft die wichtigsten HTTP-Eigenschaften. Optional steht Google API Gateway davor.

**Kosten:** Cloud Run wie in Termin 3 (im Freikontingent). API Gateway: die ersten 2 Millionen Aufrufe pro Monat kostenlos.

## Voraussetzungen

- Dienst aus [t03-container](../t03-container/README.md)
- Image `$PLACEFINDER_IMAGE:t05`

## Schritte

```bash
./update-service.sh          # Image t05 in die Artifact Registry, neue Revision
./smoke-test.sh <service-url>
```

Cloud Run legt bei jedem Deployment eine neue **Revision** an und leitet den Verkehr auf sie um, sobald sie bereit ist. Mit `gcloud run services update-traffic … --to-revisions …=10` ließe sich der Verkehr auch aufteilen (Canary). Die URL steht in `../.state/t03.env` (`SERVICE_URL`).

Der Smoke-Test prüft Statuscodes (200, 404, 422), eine bedingte Anfrage mit `If-None-Match` (erwartet 304) und zeigt die Fehlerantwort im Format `application/problem+json`.

### Optional: API Gateway

```bash
./create-api-gateway.sh      # einige Minuten
./smoke-test.sh <gateway-url>
./destroy-api-gateway.sh
```

Google API Gateway verlangt eine Beschreibung im Format **OpenAPI 2.0** (`openapi2.yaml`). Nur die dort beschriebenen Pfade gelangen zum Dienst; alles andere beantwortet das Gateway selbst mit 404. Die Erweiterung `x-google-backend` nennt das Ziel, `APPEND_PATH_TO_ADDRESS` hängt den Pfad an. Das Gateway ruft Cloud Run mit der Identität eines eigenen Service Accounts auf, der die Rolle *Cloud Run Invoker* erhält – so ließe sich der Dienst selbst auch privat schalten.

Rate Limits gibt es bei API Gateway als Kontingente pro API-Key (`x-google-quota` in der OpenAPI-Beschreibung); dafür müssen sich Clients mit einem Schlüssel ausweisen.

## Aufräumen

```bash
./destroy-api-gateway.sh       # falls angelegt
../t03-container/destroy.sh
```

## Fragen zum Weiterdenken

- Welche Aufgaben übernimmt das API Gateway, die sonst in der Anwendung stünden?
- Warum ist es ein Vorteil, dass nur beschriebene Pfade durchgelassen werden – und wann ist es lästig?
- Wie würde man Cloud Run auf `--no-allow-unauthenticated` umstellen, sodass nur noch das Gateway den Dienst erreicht?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Neue Version | Express Mode, Canary | Revision | Revision, Traffic Splitting |
| API-Gateway | API Gateway (HTTP API) | API Management (Consumption) | API Gateway |
| Rate Limit | Throttling je Stage oder Route | Richtlinie | Kontingente mit API-Keys |
