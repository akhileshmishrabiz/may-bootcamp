variable "environment" {
  description = "The environment for the resources (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "batch" {
  type    = string
  default = "may25"
}

variable "gpg_runner_sizes" {
  type = map(any)
  default = {
    "cpu" : 256
    "memory" : 2048
  }
}