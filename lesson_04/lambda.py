import os, io, json, boto3
from PIL import Image

s3 = boto3.client("s3")
BUCKET = os.environ.get("BUCKET_NAME")  # set in Configuration → Environment variables
THUMBS_PREFIX = "thumbs/"
UPLOADS_PREFIX = "uploads/"
THUMB_SIZE = (200, 200)

def handler(event, context):
    # S3 put event can contain multiple records
    for record in event.get("Records", []):
        bkt = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        # Only process uploads/ keys
        if not key.startswith(UPLOADS_PREFIX):
            continue

        # Download original
        obj = s3.get_object(Bucket=bkt, Key=key)
        img = Image.open(io.BytesIO(obj["Body"].read()))
        img.thumbnail(THUMB_SIZE)

        # Save thumbnail to memory as JPEG
        outbuf = io.BytesIO()
        img.convert("RGB").save(outbuf, format="JPEG", quality=85)
        outbuf.seek(0)

        # Upload to thumbs/
        thumb_key = THUMBS_PREFIX + os.path.basename(key).rsplit(".", 1)[0] + ".jpg"
        s3.put_object(Bucket=bkt, Key=thumb_key, Body=outbuf, ContentType="image/jpeg")

    return {"statusCode": 200, "body": json.dumps({"ok": True})}

