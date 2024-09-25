variable "cluster-name" {
  description = "the name of the cluster"
  default     = "david-friday-app"
}

variable "aws_region" {
  description = "the region of the vpc"
  default     = "us-east-1"
}

variable "prefix" {
  description = "a prefix to all of the servsis"
  default     = "david-friday-app"
}

variable "cidr_0" {
  description = "ip 0.0.0.0/0"
  default     = "0.0.0.0/0"
}

variable "argocd_ssh_location" { 
  type = string
  default = "~/.ssh/argocd-github"
}