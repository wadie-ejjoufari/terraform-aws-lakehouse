# ingestion.py
import os, json, gzip, time, hashlib
from datetime import datetime, timezone
import urllib.request, urllib.error
import boto3

S3_BUCKET = os.environ["S3_BUCKET"]
S3_PREFIX = os.environ.get("S3_PREFIX", "github/events")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
GH_TOKEN  = os.environ.get("GH_TOKEN", "")

s3 = boto3.client("s3")

API = "https://api.github.com/events"  # latest 30 public events
UA  = "terraform-aws-lakehouse-ingestor"

# Simple state in-memory per container lifetime (ok for Lambda warm starts)
ETAG = None
LAST_MOD = None

def http_get_with_retries(url, headers, max_attempts=4):
    backoff = 1.0
    for attempt in range(1, max_attempts + 1):
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return resp
        except urllib.error.HTTPError as e:
            # Respect rate limit 403/429 with Retry-After if present
            if e.code in (429, 500, 502, 503, 504) or e.code == 403:
                retry_after = float(e.headers.get("Retry-After", "0") or 0)
                sleep_for = retry_after if retry_after > 0 else backoff
                if attempt == max_attempts:
                    raise
                time.sleep(sleep_for)
                backoff *= 2
            else:
                raise
        except urllib.error.URLError:
            if attempt == max_attempts:
                raise
            time.sleep(backoff)
            backoff *= 2

def fetch_events():
    global ETAG, LAST_MOD
    headers = {"User-Agent": UA, "Accept": "application/vnd.github+json"}
    if GH_TOKEN:
        headers["Authorization"] = f"Bearer {GH_TOKEN}"
    if ETAG:
        headers["If-None-Match"] = ETAG
    if LAST_MOD:
        headers["If-Modified-Since"] = LAST_MOD

    resp = http_get_with_retries(API, headers)
    status = getattr(resp, "status", 200)
    if status == 304:
        return []  # nothing new

    data = resp.read()
    ETAG = resp.headers.get("ETag", ETAG)
    LAST_MOD = resp.headers.get("Last-Modified", LAST_MOD)
    try:
        events = json.loads(data)
        if not isinstance(events, list):
            return []
        return events
    except json.JSONDecodeError:
        return []

def to_jsonl(event):
    repo = event.get("repo") or {}
    actor = event.get("actor") or {}

    # Minimal validation
    ev_id = event.get("id")
    ev_type = event.get("type")
    created_at = event.get("created_at")
    repo_name = repo.get("name")
    actor_login = actor.get("login")
    if not (ev_id and ev_type and created_at and repo_name and actor_login):
        return None

    return json.dumps({
        "id": ev_id,
        "type": ev_type,
        "created_at": created_at,                 # ISO8601 string
        "repo_id": repo.get("id"),
        "repo_name": repo_name,
        "actor_id": actor.get("id"),
        "actor_login": actor_login,
        # keep column present in Glue; fill when you need it:
        "payload_raw": None
    }, ensure_ascii=False)

def lambda_handler(event, context):
    events = fetch_events()
    kept = []
    for ev in events:
        line = to_jsonl(ev)
        if line:
            kept.append(line)

    if not kept:
        if LOG_LEVEL == "INFO":
            print("No new events or nothing valid to write")
        return {"ok": True, "sent": 0}

    jsonl_content = "\n".join(kept) + "\n"
    compressed_data = gzip.compress(jsonl_content.encode("utf-8"))

    now = datetime.now(timezone.utc)
    # stable key includes a digest to avoid collisions across parallel invokes
    digest = hashlib.sha1(jsonl_content.encode("utf-8")).hexdigest()[:10]
    s3_key = (
        f"{S3_PREFIX}/ingest_dt={now.strftime('%Y-%m-%d')}/"
        f"{now.strftime('%Y%m%d-%H%M%S')}-{context.aws_request_id[:8]}-{digest}.json.gz"
    )

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=compressed_data,
        ContentType="application/json",
        ContentEncoding="gzip"
    )

    if LOG_LEVEL == "INFO":
        print(f"Uploaded {len(kept)} events to s3://{S3_BUCKET}/{s3_key}")
    return {"ok": True, "sent": len(kept), "s3_key": s3_key}
