variable "aws_region" {
  description = "AWS Region"
  default     = ""
}

variable "env" {
  type    = string
  default = "Course"
}
variable "secret_key" {
  type    = string
  default = ""
}
variable "access_key" {
  type    = string
  default = ""
}

variable "product" {
  type    = string
  default = ""
}

variable "dir_type" {
  type    = string
  default = "simpleAD"
}

variable "az_names" {
  type    = list(string)
  default = [""]
}

variable "vpc_cidr" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_cidr_blocks" {
  type    = list(string)
  default = [""]
}

variable "domain_name" {
}

variable "allocated_storage" {
}

variable "engine_name" {
}

variable "engine_version" {
}

variable "db_instance_type" {
}
variable "db_name" {
}

variable "username" {
}

variable "password" {
}
