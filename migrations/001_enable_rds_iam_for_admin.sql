-- Grant the rds_iam role to metadata_admin so it can authenticate using
-- IAM-issued auth tokens (instead of a password). Paired with
-- iam_database_authentication_enabled = true on the RDS instance.
GRANT rds_iam TO metadata_admin;
