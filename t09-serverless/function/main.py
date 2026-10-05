"""Cloud Run function (HTTP) for the daily GeoNames update.

Cloud Scheduler calls it once a day with an OIDC token. A manual call
may pass ?date=YYYY-MM-DD to process a specific day.
"""

import json
import logging
import os

import functions_framework
from google.cloud import storage

from geonames_sync import parse_day, run

logging.getLogger().setLevel(logging.INFO)
bucket = storage.Client().bucket(os.environ["DATA_BUCKET"])


def store(key: str, data: bytes) -> None:
    bucket.blob(key).upload_from_string(data)


@functions_framework.http
def sync(request):
    result = run(store, parse_day(request.args.get("date")))
    return json.dumps(result), 200, {"Content-Type": "application/json"}
