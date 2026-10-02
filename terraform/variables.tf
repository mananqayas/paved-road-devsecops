variable "app_version" {
  description = "Version of the sample API being deployed."
  type        = string
  default     = "0.1.0"

}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"

}