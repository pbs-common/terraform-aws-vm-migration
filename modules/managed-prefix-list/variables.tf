variable "name" {
  description = "Name of the managed prefix list."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "address_family" {
  description = "Address family of the prefix list (\"IPv4\" or \"IPv6\")."
  type        = string
  default     = "IPv4"

  validation {
    condition     = contains(["IPv4", "IPv6"], var.address_family)
    error_message = "address_family must be \"IPv4\" or \"IPv6\"."
  }
}

variable "max_entries" {
  description = "Maximum number of entries the prefix list can hold. No default: a referencing SG rule counts against the 60-rule quota by this number, not 1, so size it deliberately."
  type        = number

  validation {
    condition     = var.max_entries >= length(var.entries)
    error_message = "max_entries must be at least the number of entries in var.entries."
  }

  validation {
    condition     = var.max_entries >= 1 && floor(var.max_entries) == var.max_entries
    error_message = "max_entries must be a positive whole number."
  }
}

variable "entries" {
  description = "CIDR entries for the prefix list."
  type = list(object({
    cidr        = string
    description = optional(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to the prefix list, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}
