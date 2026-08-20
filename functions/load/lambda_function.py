import os
import boto3
import requests

s3 = boto3.client("s3")

BUCKET = os.environ["BUCKET"]
GRAPHDB = os.environ["GRAPHDB"]
REPO = os.environ["REPO"]

def lambda_handler(event, context):
    files=[]
    key=event["key"]
    rdf=s3.get_object(
        Bucket=BUCKET,
        Key=key
    )["Body"].read()

    response = requests.post(
        f"{GRAPHDB}/repositories/{REPO}/statements",
        headers={
            "Content-Type":"application/rdf+xml"
        },
        data=rdf,
        timeout=60
    )
    response.raise_for_status()
    files.append(key)
    return {
        "loaded":len(files)
    }