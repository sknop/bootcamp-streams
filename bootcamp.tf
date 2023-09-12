# Configure the Confluent Cloud Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.51.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_api_key
  cloud_api_secret = var.confluent_api_secret
}

resource "confluent_environment" "stream_bootcamp" {
  display_name = var.confluent_environment
}

locals {
  env_id = confluent_environment.stream_bootcamp.id
}

resource "confluent_kafka_cluster" "bootcamp-cluster" {
  display_name = "bootcamp-cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.confluent_region
  standard {}

  environment {
    id = local.env_id
  }
}

resource "confluent_service_account" "bootcamp-env-manager" {
  display_name = "bootcamp-env-manager"
  description  = "Service account to manage resources under 'stream_bootcamp' environment on Confluent Cloud"
}

resource "confluent_role_binding" "app-manager-env-admin" {
  principal   = "User:${confluent_service_account.bootcamp-env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.stream_bootcamp.resource_name
}

resource "confluent_role_binding" "app-manager-cluster-admin" {
  principal   = "User:${confluent_service_account.bootcamp-env-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern =  confluent_kafka_cluster.bootcamp-cluster.rbac_crn
}

resource "confluent_api_key" "env-manager-cluster-api-key" {
  display_name = "env-manager-cluster-api-key"
  description  = "Cloud API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.bootcamp-env-manager.id
    api_version = confluent_service_account.bootcamp-env-manager.api_version
    kind        = confluent_service_account.bootcamp-env-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.bootcamp-cluster.id
    api_version = confluent_kafka_cluster.bootcamp-cluster.api_version
    kind        = confluent_kafka_cluster.bootcamp-cluster.kind

    environment {
      id = confluent_environment.stream_bootcamp.id
    }
  }

  # The goal is to ensure that confluent_role_binding.app-manager-env-admin is created before
  # confluent_api_key.env-manager-cloud-api-key is used.

  depends_on = [
    confluent_role_binding.app-manager-env-admin,
    confluent_role_binding.app-manager-cluster-admin
  ]

}

locals {
  api_key = confluent_api_key.env-manager-cluster-api-key.id
  secret = confluent_api_key.env-manager-cluster-api-key.secret
}

resource "local_file" "api-key" {
  filename = "${path.module}/apikey.json"
  content = "{\n\t\"api_key\": \"${local.api_key}\",\n\t\"secret\": \"${local.secret}\"\n}"
  file_permission = "0664"
}

# --------------------------------------------------------------

resource "confluent_service_account" "bootcamp-schema-registry-manager" {
  display_name = "bootcamp_schema_registry_manager"
  description  = "Service account to manage schemas under 'stream_bootcamp' environment on Confluent Cloud"
}

resource "confluent_role_binding" "schema-registry-resource-owner" {
  principal   = "User:${confluent_service_account.bootcamp-schema-registry-manager.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${confluent_schema_registry_cluster.essentials.resource_name}/subject=*"
}

data "confluent_schema_registry_region" "bootcamp" {
  cloud   = "AWS"
  region  = var.confluent_schema_region
  package = "ESSENTIALS"
}

resource "confluent_schema_registry_cluster" "essentials" {
  package = data.confluent_schema_registry_region.bootcamp.package

  environment {
    id = confluent_environment.stream_bootcamp.id
  }

  region {
    # See https://docs.confluent.io/cloud/current/stream-governance/packages.html#stream-governance-regions
    # Schema Registry and Kafka clusters can be in different regions as well as different cloud providers,
    # but you should to place both in the same cloud and region to restrict the fault isolation boundary.
    id = data.confluent_schema_registry_region.bootcamp.id
  }
}

resource "confluent_api_key" "bootcamp-schema-registry-api-key" {
  display_name = "bootcamp-schema-registry-api-key"
  description = "Schema Registry API Key used by the bootcamp students"
  owner {
    id            = confluent_service_account.bootcamp-schema-registry-manager.id
    api_version   = confluent_service_account.bootcamp-schema-registry-manager.api_version
    kind          = confluent_service_account.bootcamp-schema-registry-manager.kind
  }

  managed_resource {
    id          = confluent_schema_registry_cluster.essentials.id
    api_version = confluent_schema_registry_cluster.essentials.api_version
    kind        = confluent_schema_registry_cluster.essentials.kind

    environment {
      id = confluent_environment.stream_bootcamp.id
    }
  }

}


locals {
  schema_api_key = confluent_api_key.bootcamp-schema-registry-api-key.id
  schema_secret = confluent_api_key.bootcamp-schema-registry-api-key.secret
}

resource "local_file" "schema-api-key" {
  filename = "${path.module}/schema-apikey.json"
  content = "{\n\t\"api_key\": \"${local.schema_api_key}\",\n\t\"secret\": \"${local.schema_secret}\"\n}"
  file_permission = "0664"
}

# --------------------------------------------------------------

resource "confluent_service_account" "app-ksql" {
  display_name = "app-ksql"
  description  = "Service account to manage 'example' ksqlDB cluster"
}

resource "confluent_role_binding" "app-ksql-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-ksql.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.bootcamp-cluster.rbac_crn
}

resource "confluent_role_binding" "app-ksql-schema-registry-resource-owner" {
  principal   = "User:${confluent_service_account.app-ksql.id}"
  role_name   = "ResourceOwner"
  crn_pattern = format("%s/%s", confluent_schema_registry_cluster.essentials.resource_name, "subject=*")
}

resource "confluent_ksql_cluster" "bootcamp" {
  display_name = "bootcamp"
  csu          = 1
  kafka_cluster {
    id = confluent_kafka_cluster.bootcamp-cluster.id
  }
  credential_identity {
    id = confluent_service_account.app-ksql.id
  }
  environment {
    id = confluent_environment.stream_bootcamp.id
  }
  depends_on = [
    confluent_role_binding.app-ksql-kafka-cluster-admin,
    confluent_role_binding.app-ksql-schema-registry-resource-owner,
    confluent_schema_registry_cluster.essentials
  ]
}

# --------------------------------------------------------------

resource "confluent_kafka_topic" "customer" {
  kafka_cluster  {
    id = confluent_kafka_cluster.bootcamp-cluster.id
  }

  topic_name       = "customer"
  partitions_count = 6
  rest_endpoint    = confluent_kafka_cluster.bootcamp-cluster.rest_endpoint
  config = {
  }
  credentials {
    key    = local.api_key
    secret = local.secret
  }
}

resource "confluent_kafka_topic" "region" {
  kafka_cluster  {
    id = confluent_kafka_cluster.bootcamp-cluster.id
  }

  topic_name       = "region"
  partitions_count = 4
  rest_endpoint    = confluent_kafka_cluster.bootcamp-cluster.rest_endpoint
  config = {
  }
  credentials {
    key    = local.api_key
    secret = local.secret
  }
}

locals {
  service_accounts = csvdecode(file("${path.module}/${var.service_accounts_file}"))
}

module "bootcamp_create_service_account" {
  count                           = length(local.service_accounts)
  api_key                         = var.confluent_api_key
  api_secret                      = var.confluent_api_secret
  source                          = "./module"
  service_account                 = element(local.service_accounts, count.index).user
  confluent_cluster_rest_endpoint = confluent_kafka_cluster.bootcamp-cluster.rest_endpoint
  confluent_cluster_version       = confluent_kafka_cluster.bootcamp-cluster.api_version
  confluent_cluster_kind          = confluent_kafka_cluster.bootcamp-cluster.kind
  confluent_cluster_id            = confluent_kafka_cluster.bootcamp-cluster.id

  confluent_api_key               = local.api_key
  confluent_cloud_api_secret      = local.secret
  env_id                          = local.env_id
}

output "bootcamp-cluster-service-account-api-key" {
  value = module.bootcamp_create_service_account
  sensitive = true
}

