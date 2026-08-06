# Scheduled GraphDB RDF load (ECS Fargate)

Weekly ECS Fargate job that syncs RDF from S3 and runs [`LoadToGraphDB.py`](../LoadToGraphDB.py) against GraphDB (modules from [`chicagopcdc/terraform_modules`](https://github.com/chicagopcdc/terraform_modules)).

**How to run:** copy `vars.tfvars.example` to `vars.tfvars` and fill in network/GraphDB settings, then `terraform init && terraform apply -var-file=./vars.tfvars`, push the image with `./scripts/load_to_ecr.sh`, and upload RDF with `LOCAL_RDF=../rdf_test ./scripts/upload_rdf.sh` (or `./scripts/upload_rdf.sh` for the full `rdf/` tree).
