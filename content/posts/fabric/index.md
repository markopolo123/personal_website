+++
title = "Using AI to analyse Terraform Plans"
date = "2025-01-30"
author = "Mark"
tags = ["fabric", "ai", "terraform", "devops", "automation"]
keywords = ["fabric", "ai", "terraform", "devops", "automation"]
description = "Using AI tools on the CLI to augment ${STUFF}"
showFullContent = false
draft = false
summary = "Using AI on the CLI to analyse Terraform Plans"
+++

# Intro

The AI hype train is in full swing, and I'm here for it. Well, sort of - I spend all
day in the CLI and have no time for fancy GUIs. Luckily, I can still get in on the fun.

It's under the radar, but [fabric](https://github.com/danielmiessler/fabric) is a
cool CLI tool for interacting with the APIs of various LLM providers. You can declare
patterns and call them as prompts in your shell. I've not seen many people using it for
platform engineering work and wanted to give an example of how it might be useful.

So, here's an example of a simple `fabric` pattern for working with Terraform plans:

```bash
💀5% ✗  cat ~/.config/fabric/patterns/analyze_terraform_plan/system.md
```

```markdown
# IDENTITY and PURPOSE

You are an expert Terraform plan analyser. You take Terraform plan outputs and generate a Markdown formatted summary using the format below.

You focus on assessing infrastructure changes, security risks, cost implications, and compliance considerations.

# OUTPUT SECTIONS
* Combine all of your understanding of the Terraform plan into a single, 20-word sentence in a section called ONE SENTENCE SUMMARY:.
* Output the 10 most critical changes, optimisations, or concerns from the Terraform plan as a list with no more than 16 words per point into a section called MAIN POINTS:.
* Output a list of the 5 key takeaways from the Terraform plan in a section called TAKEAWAYS:.

# OUTPUT INSTRUCTIONS
* Create the output using the formatting above.
* You only output human-readable Markdown.
* Output numbered lists, not bullets.
* Do not output warnings or notes—just the requested sections.
* Do not repeat items in the output sections.
* Do not start items with the same opening words.
# INPUT:

INPUT:
```

Here's the output of the pattern in action:

```bash
💀3% ✗  terraform plan | fabric --pattern analyze_terraform_plan
```

```markdown

# ONE SENTENCE SUMMARY:

A single `null_resource` will be created, with its ID outputted after apply, with no other changes planned.

# MAIN POINTS:
01. A `null_resource` named "example" will be added to the infrastructure.
02. The resource's ID will only be known after the plan is applied.
03. No existing resources will be modified or destroyed in this execution.
04. Outputs will include the ID of the newly created `null_resource`.
05. The plan does not include any security-specific or cost-impacting resources.
06. The addition of the `null_resource` is purely for placeholder or logical grouping purposes.
07. No actual infrastructure or cloud resources are provisioned with this plan.
08. This plan ensures no unintended changes to the current infrastructure state.
09. The absence of the `-out` option means the plan isn't saved for exact future application.
10. Running `terraform apply` will implement the described single change with minimal operational risk.
# TAKEAWAYS:
01. The plan is minimal, adding only a single `null_resource`.
02. No significant infrastructure, security, or cost changes are included in this plan.
03. Outputs confirm the creation of the new resource's ID.
04. The execution poses no compliance or operational risks due to its simplicity.
05. Saving the plan using `-out` is recommended for future reproducibility.
```

Pretty rad, right. I've not come up with any other uses for fabric yet in my `$DAYJOB` , 
 but I could see this being used in a CI pipeline to check for compliance or security issues in Terraform plans.
