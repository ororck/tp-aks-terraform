variable "owner" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "cluster_egress_ip" { type = string }
variable "deployer_principal_id" { type = string }
variable "tags" { type = map(string) }
