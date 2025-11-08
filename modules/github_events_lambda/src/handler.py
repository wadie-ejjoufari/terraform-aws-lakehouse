import os, json, gzip
from datetime import datetime
import urllib.request
import boto3

S3_BUCKET = os.environ.get("S3_BUCKET")
S3_PREFIX = os.environ.get("S3_PREFIX", "github/events")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
GH_TOKEN  = os.environ.get("GH_TOKEN", "")

s3 = boto3.client("s3")

API = "https://api.github.com/events"  # public events
UA  = "terraform-aws-lakehouse-ingestor"

def fetch_events():
    req = urllib.request.Request(API, headers={"User-Agent": UA})
    if GH_TOKEN:
        req.add_header("Authorization", f"Bearer {GH_TOKEN}")
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = resp.read()
        events = json.loads(data)
        return events

# Convert GH event to a compact JSON line suitable for S3 Bronze
def to_jsonl(event):
    repo = event.get("repo", {})
    actor = event.get("actor", {})
    return json.dumps({
        "id": event.get("id"),
        "type": event.get("type"),
        "created_at": event.get("created_at"),
        "repo_id": repo.get("id"),
        "repo_name": repo.get("name"),
        "actor_id": actor.get("id"),
        "actor_login": actor.get("login"),
        # optionally keep raw payload: "payload_raw": json.dumps(event.get("payload", {}))
    })

def lambda_handler(event, context):
    events = fetch_events()

    # Create JSONL content
    jsonl_lines = []
    for ev in events:
        jsonl_lines.append(to_jsonl(ev))

    jsonl_content = "\n".join(jsonl_lines) + "\n"

    # Compress with gzip
    compressed_data = gzip.compress(jsonl_content.encode("utf-8"))

    # Generate S3 key with timestamp partitioning
    now = datetime.utcnow()
    s3_key = f"{S3_PREFIX}/ingest_dt={now.strftime('%Y-%m-%d')}/{now.strftime('%Y%m%d-%H%M%S')}-{context.aws_request_id}.json.gz"

    # Upload to S3
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=compressed_data,
        ContentType="application/json",
        ContentEncoding="gzip"
    )

    if LOG_LEVEL == "INFO":
        print(f"Uploaded {len(events)} events to s3://{S3_BUCKET}/{s3_key}")

    return {"ok": True, "sent": len(events), "s3_key": s3_key}
