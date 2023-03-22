# bootcamp-streams
Preparation for KStreams bootcamp in Confluent Cloud

This repo is used to create

- An environment called "bootcamp"
- A **BASIC** cluster called "bootcamp-cluster"
- An **ESSENTIAL** schema registry in a free region

We also create a service account for the data generators and 
an appropriate API Key, which will be stored as "apikey.json" 
in the local project folder.

Additionally, we will create a schema registry key for the
generators and students alike, stored in "schema-apikey.json"
in the same location.

We will then process a list of users referred to by the variable
_service_accounts_file_, which is expected to be a CSV file with
the first line containing the words 

  ```user,email```

Followed by a list of users with their (preferred) name for the 
service account and email address (not used by this terraform 
script, but used when generating invites for the CC bootcamp)

The cloud API key required to create the environment and cluster 
can be added to `terraform.tfvars`, or, preferrably, in the 
environment. I use `direnv` for that purpose and update `.envrc`.

```shell
export TF_VAR_confluent_api_key="YOUR KEY"
export TF_VAR_confluent_api_secret="YOUR SECRET"
```
