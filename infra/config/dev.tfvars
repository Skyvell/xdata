region = "eu-north-1"

catalog_instance_class          = "db.t4g.micro"
catalog_multi_az                = false
catalog_backup_retention_period = 0
catalog_skip_final_snapshot     = true
catalog_deletion_protection     = false

catalog_allowed_cidrs = ["217.119.174.244/32"]

# Dagster+ subdomain prefix — everything before .dagster.plus in your UI URL.
# Also create secret 'ducklake/dagster-cloud-agent-token' in AWS Secrets Manager (eu-north-1)
# with the raw agent token as plaintext before `tofu apply`.
dagster_org_slug = "tedskyvell.eu"
