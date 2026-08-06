variable "owner_slug" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "kubelet_principal_id" { type = string }
variable "ci_principal_id" { type = string }
variable "tags" { type = map(string) }