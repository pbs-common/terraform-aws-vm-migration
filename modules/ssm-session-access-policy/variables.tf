variable "name" {
  description = "Name of the IAM policy."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "tags" {
  description = "Tags an instance must carry to be reachable via this policy. Also applied as tags on the policy itself."
  type        = map(string)

  validation {
    condition     = length(var.tags) > 0
    error_message = "tags must contain at least one key/value pair."
  }
}
