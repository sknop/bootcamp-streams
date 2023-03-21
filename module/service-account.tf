terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 1.35.0"
    }
  }
}

variable "api_key" {
  type = string
}

variable "api_secret" {
  type      = string
  sensitive = true
}

variable "confluent_api_key" {
  type = string
}

variable "confluent_cloud_api_secret" {
  type      = string
  sensitive = true
}

variable "confluent_cluster_rest_endpoint" {
  type = string
}

variable "confluent_cluster_id" {
  type = string
}

variable "confluent_cluster_version" {
  type = string
}

variable "confluent_cluster_kind" {
  type = string
}

variable "service_account" {
  type = string
}

variable "env_id" {
  type = string
}

resource "confluent_service_account" "sa" {
  display_name = var.service_account
  description  = "Service Account for ${var.service_account}"
}


resource "confluent_kafka_acl" "describe" {
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.sa.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = var.confluent_cluster_rest_endpoint
  credentials {
    key    = var.confluent_api_key
    secret = var.confluent_cloud_api_secret
  }
}

resource "confluent_kafka_acl" "customer" {
  for_each      = toset(["READ", "DESCRIBE", "DESCRIBE_CONFIGS"])
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  resource_type = "TOPIC"
  resource_name = "customer"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.sa.id}"
  host          = "*"
  permission    = "ALLOW"
  rest_endpoint = var.confluent_cluster_rest_endpoint
  operation     = each.key
  credentials {
    key    = var.confluent_api_key
    secret = var.confluent_cloud_api_secret
  }
}

resource "confluent_kafka_acl" "region" {
  for_each      = toset(["READ", "DESCRIBE", "DESCRIBE_CONFIGS"])
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  resource_type = "TOPIC"
  resource_name = "region"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.sa.id}"
  host          = "*"
  permission    = "ALLOW"
  rest_endpoint = var.confluent_cluster_rest_endpoint
  operation     = each.key
  credentials {
    key    = var.confluent_api_key
    secret = var.confluent_cloud_api_secret
  }
}

resource "confluent_kafka_acl" "prefixed" {
  for_each      = toset(["READ", "WRITE", "CREATE", "DELETE", "ALTER", "DESCRIBE", "DESCRIBE_CONFIGS", "ALTER_CONFIGS", "IDEMPOTENT_WRITE"])
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  resource_type = "TOPIC"
  resource_name = var.service_account
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.sa.id}"
  host          = "*"
  operation     = each.key
  permission    = "ALLOW"
  rest_endpoint = var.confluent_cluster_rest_endpoint
  credentials {
    key    = var.confluent_api_key
    secret = var.confluent_cloud_api_secret
  }
}

resource "confluent_kafka_acl" "group" {
  for_each      = toset(["READ", "WRITE", "CREATE", "DELETE", "ALTER", "DESCRIBE", "DESCRIBE_CONFIGS", "ALTER_CONFIGS", "IDEMPOTENT_WRITE"])
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  resource_type = "GROUP"
  resource_name = var.service_account
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.sa.id}"
  host          = "*"
  operation     = each.key
  permission    = "ALLOW"
  rest_endpoint = var.confluent_cluster_rest_endpoint
  credentials {
    key    = var.confluent_api_key
    secret = var.confluent_cloud_api_secret
  }
}

resource "confluent_kafka_acl" "transaction" {
  for_each      = toset(["READ", "WRITE", "CREATE", "DELETE", "ALTER", "DESCRIBE", "DESCRIBE_CONFIGS", "ALTER_CONFIGS", "IDEMPOTENT_WRITE"])
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  resource_type = "TRANSACTIONAL_ID"
  resource_name = var.service_account
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.sa.id}"
  host          = "*"
  operation     = each.key
  permission    = "ALLOW"
  rest_endpoint = var.confluent_cluster_rest_endpoint
  credentials {
    key    = var.confluent_api_key
    secret = var.confluent_cloud_api_secret
  }
}

resource "confluent_api_key" "sa-api-key" {
  display_name = "sa-api-key"
  description  = "Kafka API Key that is owned by ${var.service_account} service account"
  owner {
    id          = confluent_service_account.sa.id
    api_version = confluent_service_account.sa.api_version
    kind        = confluent_service_account.sa.kind
  }

  managed_resource {
    id          = var.confluent_cluster_id
    api_version = var.confluent_cluster_version
    kind        = var.confluent_cluster_kind

    environment {
      id = var.env_id
    }
  }
}


output "bootcamp-cluster-api-key" {
  value = confluent_api_key.sa-api-key.id
}

output "bootcamp-cluster-api-secret" {
  value = confluent_api_key.sa-api-key.secret
  sensitive = true
}

resource "local_file" "api-key" {
  filename = "${path.module}/${var.service_account}.json"
  content = "{\n\t\"api_key\": \"${confluent_api_key.sa-api-key.id}\",\n\t\"secret\": \"${confluent_api_key.sa-api-key.secret}\"\n}"
  file_permission = "0664"
}

output "bootcamp-cluster-sa" {
  value = confluent_service_account.sa
}
