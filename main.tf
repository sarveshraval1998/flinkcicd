terraform {
  cloud {
    organization = "flink_cnewcloud"

    workspaces {
      name = "cicd_flink_cnewcloud"
    }
  }

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.56.0"
    }
  }
}
locals {
  cloud  = "AWS"
  region = "us-east-2"
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

data "confluent_environment" "existing_env" {
  display_name = var.confluent_environment
}

data "confluent_kafka_cluster" "existing_cluster" {
  display_name = var.confluent_cluster 

  environment {
    id = data.confluent_environment.existing_env.id
  }
}


# Create a new Service Account. This will used during Kafka API key creation and Flink SQL statement submission.
data "confluent_service_account" "existing_service_account" {
  display_name = var.confluent_service_account
  # You may need to provide additional filters to uniquely identify the existing service account
}

data "confluent_organization" "my_org" {}

data "confluent_flink_compute_pool" "existing_compute_pool" {
  display_name = var.confluent_compute_pool
  environment {
    id = data.confluent_environment.existing_env.id
  }
}

# Create a Flink-specific API key that will be used to submit statements.
data "confluent_flink_region" "my_flink_region" {
  cloud  = local.cloud
  region = local.region
}

# Deploy a Flink SQL statement to Confluent Cloud.
resource "confluent_flink_statement" "my_new_flinkstatement" {
  compute_pool {
    id = data.confluent_flink_compute_pool.existing_compute_pool.id
  }

  principal {
    id = data.confluent_service_account.existing_service_account.id
  }

  # This SQL reads data from source_topic, filters it, and ingests the filtered data into sink_topic.
  statement = <<EOT
    select *from flinktopicAPIcreation;
    EOT

  properties = {
    "sql.current-catalog"  = data.confluent_environment.existing_env.display_name
    "sql.current-database" = data.confluent_kafka_cluster.existing_cluster.display_name
  }

  rest_endpoint = var.confluent_flink_endpoint
 
  credentials {    
    key    = var.confluent_flink_keyid
    secret = var.confluent_flink_keysecret
  }
}
