output "database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.db.name
}

output "workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.wg.name
}

output "bronze_table_name" {
  description = "Name of the bronze layer Glue catalog table"
  value       = aws_glue_catalog_table.github_events_bronze.name
}
