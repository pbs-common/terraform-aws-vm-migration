# TFLint configuration for this repository.
#
# WHY THIS FILE EXISTS: without a config declaring the AWS plugin, `tflint --init`
# installs nothing and only the bundled `ruleset.terraform` runs -- naming, unused
# declarations, deprecated syntax. Every AWS-specific check (invalid instance types,
# malformed ARNs, deprecated provider arguments, invalid IAM policy shapes) is then
# silently absent, while CI still shows a green "Run TFLint" step.
#
# Measured on 2026-09-11 with the pinned 0.64.0, before this file existed:
#     TFLint version 0.64.0
#     + ruleset.terraform (0.15.0-bundled)
# Only the bundled ruleset. This repository is almost entirely AWS resources, which
# is precisely the surface the bundled ruleset does not cover.
#
# See issue #38.

config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
