import boto3
import requests

s3 = boto3.client("s3")

BUCKET = "rdf-bucket"
def handler(event, context):
    profile = event
    response = requests.get(profile["rdf_link"])
    response.raise_for_status()
    filename = profile["rdf_link"].split("/")[-1]
    s3.put_object(
        Bucket=BUCKET,
        Key=f"rdf/{filename}",
        Body=response.content,
    )

    return {
        "key": f"rdf/{filename}"
    }