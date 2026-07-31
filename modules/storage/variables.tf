variable "owner_slug" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "account_tier" { type = string }
variable "replication" { type = string }
variable "cluster_egress_ip" { type = string }
variable "tags" { type = map(string) }
variable "ci_principal_id" { type = string }
