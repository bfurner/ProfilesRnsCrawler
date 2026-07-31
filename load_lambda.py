import boto3
import requests

s3 = boto3.client("s3")

BUCKET = "rdf-bucket"
GRAPHDB="http://localhost:7200"
REPO="profiles"

def handler(event, context):
    files=[]
    paginator=s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET,Prefix="rdf/"):
        for obj in page.get("Contents",[]):
            key=obj["Key"]
            rdf=s3.get_object(
                Bucket=BUCKET,
                Key=key
            )["Body"].read()

            requests.post(
                f"{GRAPHDB}/repositories/{REPO}/statements",
                headers={
                    "Content-Type":"application/rdf+xml"
                },
                data=rdf
            )
            files.append(key)
    return {
        "loaded":len(files)
    }