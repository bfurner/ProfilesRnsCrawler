import os
import time

import boto3
import requests
from rdflib import Graph

s3 = boto3.client("s3")

BUCKET = os.environ["BUCKET"]

max_retries = 3

def lambda_handler(event, context):
    profile = event
    for attempt in range(max_retries):
        try:
            response = requests.get(profile["rdf_link"], timeout=60)
            response.raise_for_status()

            content_type = response.headers.get("Content-Type", "").lower()
            if "application/rdf+xml" not in content_type and "application/xml" not in content_type:
                raise ValueError(
                    f"Unexpected Content-Type: {content_type}"
                )
            graph = Graph()
            graph.parse(data=response.content, format="xml")
            break
        
        except (requests.RequestException, ValueError) as e:
            if attempt == max_retries - 1:
                raise RuntimeError(
                    f"Failed to download and validate RDF"
                    f"after {max_retries} attempts"
                ) from e

            time.sleep (2 ** attempt)

    filename = profile["rdf_link"].split("/")[-1]
    s3.put_object(
        Bucket=BUCKET,
        Key=f"rdf/{filename}",
        Body=response.content,
    )

    return {
        "key": f"rdf/{filename}"
    }