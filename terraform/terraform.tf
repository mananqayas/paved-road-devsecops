terraform {

  required_version = ">= 1.9.0"
  required_providers {

    null = {

      source  = "hashicorp/null"
      version = "~> 3.2"

    }
  }

}

# Phase 1.0: no cloud resources, keeps cost at $0 and the pipeline green
# withoput credentials. Real infra (Phase 3.0 Checkov targets) comes later.
# This null_resource stands in for "the thing the pipeline deploys."

resource "null_resource" "sample_api" {
  triggers = {
    app_version = var.app_version
  }

}