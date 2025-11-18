terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Glue database for lakehouse
resource "aws_glue_catalog_database" "db" {
  name = replace("${var.name_prefix}-lake", "_", "-")
}

# Athena workgroup with encrypted, per-env output location
resource "aws_athena_workgroup" "wg" {
  name  = "${var.name_prefix}-wg"
  state = "ENABLED"
  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/athena-results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }
  }
  tags = var.tags
}
# Bronze external table (partition projection, no crawler, schema defined manually)
# Data expected under s3://<raw_bucket>/github/events/ingest_dt=YYYY-MM-DD/
resource "aws_glue_catalog_table" "github_events_bronze" {
  name          = "github_events_bronze"
  database_name = aws_glue_catalog_database.db.name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    classification                = "json"
    "projection.enabled"          = "true"
    "projection.ingest_dt.type"   = "date"
    "projection.ingest_dt.range"  = "2024-01-01,NOW"
    "projection.ingest_dt.format" = "yyyy-MM-dd"
    "storage.location.template"   = "s3://${var.raw_bucket}/github/events/ingest_dt=$${ingest_dt}/"
    has_encrypted_data            = "true"
  }
  storage_descriptor {
    location      = "s3://${var.raw_bucket}/github/events/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "id"
      type = "string"
    }
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "created_at"
      type = "string"
    }
    columns {
      name = "repo_id"
      type = "bigint"
    }
    columns {
      name = "repo_name"
      type = "string"
    }
    columns {
      name = "actor_id"
      type = "bigint"
    }
    columns {
      name = "actor_login"
      type = "string"
    }
    columns {
      name = "payload_raw"
      type = "string"
    }

    compressed = false
  }

  partition_keys {
    name = "ingest_dt"
    type = "string"
  }
}

# Silver table (CTAS-managed, Parquet format)
resource "aws_glue_catalog_table" "github_events_silver" {
  name          = "github_events_silver"
  database_name = aws_glue_catalog_database.db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification     = "parquet"
    has_encrypted_data = "true"
  }

  storage_descriptor {
    location      = "s3://${var.silver_bucket}/github/events_silver/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "event_id"
      type = "string"
    }
    columns {
      name = "event_type"
      type = "string"
    }
    columns {
      name = "event_date"
      type = "date"
    }
    columns {
      name = "repo_name"
      type = "string"
    }
    columns {
      name = "actor_login"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
}

# Gold: daily aggregates of events per repo & type
resource "aws_glue_catalog_table" "github_events_gold_daily" {
  name          = "github_events_gold_daily"
  database_name = aws_glue_catalog_database.db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification     = "parquet"
    has_encrypted_data = "true"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket}/github/events_gold_daily/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "ingest_dt"
      type = "date"
    }
    columns {
      name = "event_type"
      type = "string"
    }
    columns {
      name = "repo_name"
      type = "string"
    }
    columns {
      name = "events_count"
      type = "bigint"
    }

    compressed = true
  }

  partition_keys {
    name = "ingest_dt"
    type = "date"
  }
}
