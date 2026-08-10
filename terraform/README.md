# Scheduled GraphDB RDF load (AWS Batch)

Weekly AWS Batch (Fargate) job that syncs RDF from S3 and runs [`LoadToGraphDB.py`](../LoadToGraphDB.py) against GraphDB (S3/ECR/SNS modules from [`chicagopcdc/terraform_modules`](https://github.com/chicagopcdc/terraform_modules)).

**How to run:** copy `vars.tfvars.example` to `vars.tfvars` and fill in network/GraphDB settings, then `terraform init && terraform apply -var-file=./vars.tfvars`, push the image with `./scripts/load_to_ecr.sh`, and upload RDF with `./scripts/upload_rdf.sh` (defaults to `rdf_test/`; use `LOCAL_RDF=../rdf ./scripts/upload_rdf.sh` for the full `rdf/` tree). Submit a test job with `aws batch submit-job --job-name test-load --job-queue "$(terraform output -raw batch_job_queue_arn)" --job-definition "$(terraform output -raw batch_job_definition_arn)"`.
