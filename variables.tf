variable "confluent_api_key" {
  type = string
}

variable "confluent_api_secret" {
  type      = string
  sensitive = true
}

variable "confluent_region" {
  type = string
}

variable "confluent_schema_region" {
  type = string
}

variable "confluent_environment" {
  type = string
}

variable "confluent_env_id" {
  type    = string
  default = ""
}

variable "service_accounts_file" {
  type = string
}
