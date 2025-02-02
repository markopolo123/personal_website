--- 
title: "Using Minio as a backend for Terraform"
date: "2022-06-09"
author: "Mark"
tags: ["Terraform", "Minio"]
keywords: ["terraform", "minio"]
description: "Using Minio as a backend for Terraform"
showFullContent: false
draft: false
---

# Hi There! 👋

I've been doing a lot more with self hosting recently and wondered if it were
possible to use
[Minio](https://docs.min.io/minio/baremetal/console/minio-console.html#configuration)
as a backend for [Terraform](https://www.terraform.io).

> Spoiler... it is. TLDR; link to the code is at the bottom of the article

# Configuring Minio

I already have Minio running locally, so all I needed to do was configure a
service account and create a bucket to store the state in.

Make a note of the service account's `access key` and `secret key` and the
bucket name.

# Writing the Terraform

As Minio is S3 compatible, I should be able to use the [S3 Terraform
backend](https://www.terraform.io/language/settings/backends/s3) and point it at
my bucket instead.

```hcl
terraform {
  backend "s3" {
    bucket = "test"
    key    = "demo.tfstate"

    region                      = "main"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

The credentials and S3 endpoint could be defined in the backend configuration or
provided as environment variables:

```bash
export AWS_S3_ENDPOINT=replace-with-minio-url
export AWS_ACCESS_KEY_ID=replace-with-access-key
export AWS_SECRET_ACCESS_KEY=replace-with-secret-key
```

That's all you need to get started!

A repository showing a working example is on
[Github](https://github.com/markopolo123/minio-terraform-example)
