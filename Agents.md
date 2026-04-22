# AGENTS.md — Terraform + Azure Conventions

Instructions for AI coding assistants (GitHub Copilot, Claude Code) and reference for humans working in this repository. This file defines how we write Terraform for Azure.

Follow these rules when generating, refactoring, or reviewing Terraform code in this repo. When a rule conflicts with a user request, ask before deviating.

**For human readers:** the short italic notes under many rules explain *why* the rule exists. They're not instructions to the AI — they're the reasoning that makes the rules make sense.

---

## Table of contents

1. [File organization](#1-file-organization)
2. [Variables](#2-variables)
3. [Locals](#3-locals)
4. [Outputs](#4-outputs)
5. [Resources and data sources](#5-resources-and-data-sources)
6. [Loops and data transformation](#6-loops-and-data-transformation)
7. [Functions](#7-functions)
8. [Modules — structure and API](#8-modules--structure-and-api)
9. [Modules — boundaries and design](#9-modules--boundaries-and-design)
10. [Providers and versions](#10-providers-and-versions)
11. [Backends and state](#11-backends-and-state)
12. [Naming conventions](#12-naming-conventions)
13. [Security defaults](#13-security-defaults)
14. [Anti-patterns](#14-anti-patterns)
15. [Open questions](#15-open-questions)

---

## 1. File organization

### One block type per file

| File | Contains only |
| --- | --- |
| `terraform.tf` | `terraform {}` block, `provider {}` blocks |
| `variables.tf` | `variable {}` blocks |
| `locals.tf` | `locals {}` blocks |
| `main.tf` | `resource`, `data`, and `module` blocks |
| `outputs.tf` | `output {}` blocks |

No file mixes block types.

*Why: when someone needs to change a variable, they open `variables.tf`. When they need to understand what a configuration creates, they open `main.tf`. Mixed files force them to search. Predictable file names are a form of documentation.*

### Splitting `main.tf`

Split `main.tf` when it exceeds ~150 lines **and** contains logically distinct resource groups. Split by topic, never by lifecycle or team ownership.

- Good: `compute.tf`, `networking.tf`, `storage.tf`, `identity.tf`, `monitoring.tf`.
- Bad: `create.tf`/`update.tf`, `alice.tf`/`bob.tf`.

### Data sources

- Data sources tied to a specific resource live in the same file as that resource.
- `data "azurerm_client_config" "current"` — used broadly — goes at the top of `main.tf`.
- When data sources proliferate, move them to `data.tf`.

---

## 2. Variables

### Every `variable` block is fully declared

Every variable must include:

- `type` — never rely on implicit typing. Never use `type = any`.
- `description` — one line explaining what it is and what it affects.
- `validation` — when the valid input space is narrower than the type allows.

`default` is included only when the input is genuinely optional. Required inputs have no default.

*Why: variables are the module's public API. A variable without a description is an undocumented parameter. Without validation, bad inputs fail at apply time with confusing Azure errors instead of at plan time with clear messages. Without a type, Terraform can't catch type errors early.*

### Organization within `variables.tf`

- Required variables first, optional variables second, grouped by concern.
- Use comment headers to separate groups:

```hcl
# ── Required Variables ──────────────────
variable "app_name" { ... }

# ── Optional Variables — Feature Flags ──
variable "enable_monitoring" { ... }
```

### Group related settings into typed objects

When multiple values describe one thing (Key Vault config, diagnostic settings, subnet definition), declare them as a single `object({...})` variable.

- Use `optional(type, default)` for attributes with sensible defaults. Requires Terraform >= 1.3.
- Use a second `validation` block for cross-attribute rules.

*Why: a module with 40 flat variables is not a usable interface. Grouping related inputs into objects is the same discipline as grouping related parameters into a struct in any other language.*

### Nesting depth

Two to three levels of object nesting is maintainable. Beyond that, flatten or split.

### Collection variables — pick the right type

- `list(T)` — ordered, allows duplicates. Use when order matters.
- `set(T)` — unordered, unique. Use when order doesn't matter and you want `for_each` directly.
- `map(T)` — key/value pairs. Use for tags and simple lookups.
- `map(object({...}))` — collections of structured items (subnets, NSG rules, role assignments). The most important variable type for production Terraform.

### Map keys are identities

For `map(object)` inputs that drive `for_each`, the map key is the Terraform resource identifier. **Renaming a key destroys and recreates the resource.** Pick keys that reflect stable identity.

*Why: this is the single most important thing to understand about `for_each`. Positional identity (a list) vs. named identity (a map) is why maps are safer — remove `"app"` from a map and only `"app"` is affected. Remove the middle item from a list and everything after it renumbers and gets destroyed/recreated.*

### Sensitive variables

- Set `sensitive = true`.
- Do not include a `default`.
- Describe in the `description` how to provide the value safely — typically `TF_VAR_<n>` environment variable or a CI secret, never a `.tfvars` file.
- **`sensitive = true` is display-only, not access control.** The value still flows to resources normally and appears in state as plaintext.

### Separate secrets from configuration

Do not mark an entire object variable `sensitive = true` because one attribute is a secret. It redacts every attribute including non-sensitive ones, making plans unreadable. Split the secret into its own standalone variable.

```hcl
variable "sql_server_config" {
  type = object({
    name                = string
    administrator_login = string
    version             = optional(string, "12.0")
  })
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}
```

### Validation patterns

- "One of N values": `contains(["a", "b", "c"], var.x)`.
- Format check: `can(regex("^pattern$", var.x))`. Always wrap `regex()` in `can()` — bare regex throws on no-match.
- Every element of a collection: `alltrue([for item in var.xs : <condition>])`.
- Cross-attribute dependency inside an object: a second `validation` block referencing both attributes.

### Validation error messages

State what *is* valid and why, not just that the input is wrong.

```hcl
error_message = "min_tls_version must be TLS1_0, TLS1_1, or TLS1_2. TLS1_2 is recommended for security."
```

---

## 3. Locals

### Locals are the computation layer

Derive values once in `locals`, reference them in resources. Do not embed computations inline in resource arguments.

This applies to:

- Numeric sizing
- Name construction
- Tag merging
- Data structure preparation (`for` expressions)
- Environment-specific lookups

*Why: a resource argument that reads `name = local.storage_account_name` tells you what it is. A resource argument that reads `name = substr(lower(replace("st${var.app}${substr(var.env, 0, 1)}001", "-", "")), 0, 24)` tells you nothing. The `local` name is the documentation.*

### Five categories of `locals.tf` content

1. **Resource naming** — all names computed once, referenced as `local.<n>_name`.
2. **Tag assembly** — merge base tags with caller-provided extras.
3. **Derived configuration** — per-environment sizing, retention, replica counts.
4. **Lookup results** — `lookup({ dev = ..., prod = ... }, var.environment, default)` for env-specific SKUs.
5. **Data structure preparation** — `for` expressions reshaping variables for `for_each`.

### Naming conventions for locals

| What it is | Convention | Example |
| --- | --- | --- |
| Resource name | Describe what it IS | `resource_group_name`, `key_vault_name` |
| Boolean | Prefix `is_`, `has_`, `enable_`, `use_` | `is_production`, `has_private_endpoint` |
| Value with units | Suffix makes units clear | `retention_days`, `disk_size_gb` |
| Collection | Noun or noun phrase | `all_tags`, `subnet_map` |
| Never | Generic, meaningless names | `config`, `data`, `values` |

### The naming pattern

Compute all resource names in a central `locals` block that normalizes inputs once (`lower()`, `replace()`, `substr()`):

```hcl
locals {
  app = lower(replace(var.app_name, "-", ""))
  env = substr(lower(var.environment), 0, 4)

  resource_group_name  = "rg-${var.app_name}-${var.environment}"
  storage_account_name = "st${local.app}${local.env}001"
}
```

### The tag merging pattern

```hcl
locals {
  all_tags = merge(
    { environment = var.environment, managed_by = "terraform" },
    coalesce(var.extra_tags, {})
  )
}
```

Use `coalesce(var.extra_tags, {})` because the caller's map may be null.

### Other rules

- Multiple `locals {}` blocks per file are fine — group by concern.
- Never put secrets as string literals in locals. State stores them plaintext.
- Locals compute infrastructure configuration, not application business logic.

---

## 4. Outputs

### Every output has

- `description` — required. Explains what the value is and when to use it.
- `value` — the expression.
- `sensitive = true` — for credentials, keys, connection strings.

### Modules vs. root

- **Modules are generous with outputs.** Expose every resource ID, every name, every endpoint, every attribute callers might reference. Missing outputs cost more than extra outputs.
- **Root outputs are selective.** Focus on deployment summaries and identifiers shown after `apply`.

*Why: adding an output to a module later requires every caller to upgrade. Adding an extra output costs nothing — there's no runtime penalty. Asymmetric cost means default to more outputs.*

### Canonical outputs for any Azure resource module

- `id`
- `name`
- Primary endpoint / URI
- Connection string or access key (sensitive)
- Identity `principal_id` (for role assignments)

### Output shape mirrors input shape

If the caller passes a map keyed by name, outputs are maps keyed by the same names.

```hcl
# Input:  storage_accounts = { "appdata001" = {...}, "backups001" = {...} }
# Output: same keys

output "storage_accounts" {
  value = {
    for k, v in azurerm_storage_account.this : k => {
      id   = v.id
      name = v.name
    }
  }
}
```

*Why: this lets Module A's output feed Module B's input with zero transformation. Composability depends on predictable shape.*

### Structured outputs over flat lists

Group related outputs into one structured object per logical resource type. Don't write `kv_id`, `kv_name`, `kv_uri` as three separate outputs — write one `key_vault` output containing all three.

### Full resource vs. curated

| | Internal team modules | Shared/published modules |
| --- | --- | --- |
| `value = azurerm_x.this` (full resource) | Acceptable | Avoid |
| Explicit curated attribute map | Recommended | Required |

*Why: outputting the full resource couples callers to the provider schema. When the provider upgrades and renames an attribute, every caller's code breaks.*

### `for_each` resources produce maps

```hcl
output "subnet_ids" {
  description = "Map of subnet names to subnet IDs."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}
```

Never one output per instance.

### Sensitive output rules

- `sensitive = true` only suppresses display. State still contains plaintext.
- Any root output referencing a sensitive module output must also be `sensitive = true`.
- A structured output cannot be partly sensitive — if any nested value is sensitive, mark the whole object `sensitive = true` or split into separate outputs.
- Prefer outputting IDs over secrets. Let downstream consumers read secrets from Azure using managed identity.

### Multi-line descriptions

For outputs that need to explain structure or usage, use `<<-EOT` heredoc:

```hcl
output "virtual_network" {
  description = <<-EOT
    Virtual network resource attributes.
    Contains: id, name, location, address_space, guid
    Usage: module.<n>.virtual_network.id
  EOT
  value = { ... }
}
```

---

## 5. Resources and data sources

### Resources reference `var.*` and `local.*`

Do not put computation logic inline in resource arguments. All derived values live in `locals`.

### Data source placement

- **Inside a module** when the data is always needed and never varies per caller. Example: `azurerm_client_config` for `tenant_id`.
- **In root configuration** when the data source is shared, conditional, or represents pre-existing infrastructure. Pass the looked-up ID into modules as a variable.

*Why: a module that hardcodes a Log Analytics workspace lookup is locked to environments that have that exact workspace with that exact name. Moving the lookup to root keeps the module environment-agnostic and testable.*

### Conditional data sources

```hcl
data "azurerm_log_analytics_workspace" "shared" {
  count               = var.enable_diagnostics ? 1 : 0
  name                = var.workspace_name
  resource_group_name = var.workspace_rg
}
```

Reference with `one(data.<...>.shared[*].id)`.

### No `depends_on` when references already create the dependency

Passing an output to an input or a resource attribute to another resource creates an implicit dependency. Terraform orders operations automatically. Use `depends_on` only when the dependency truly isn't expressible through references (rare).

---

## 6. Loops and data transformation

### `for_each` over `map(object)` — the default

For any time you create multiple similar resources:

```hcl
variable "subnets" {
  type = map(object({
    address_prefix    = string
    service_endpoints = optional(set(string), [])
  }))
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets
  name     = each.key
  # ...
}
```

`each.key` is the map key. `each.value` is the object.

### `for_each` over another resource's map

```hcl
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_subnet.this
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.this.id
}
```

No key enumeration needed.

### `for_each` with a set

Use `for_each = toset(var.names)` when only the key matters. Wrap `list(string)` with `toset(...)` — lists cannot feed `for_each` directly.

### `count` — narrow uses only

- Conditional resources: `count = var.enable_feature ? 1 : 0`.
- Truly identical instances differentiated only by numeric index.

Reference outputs with `one(resource.x[*].attr)` for 0-or-1 resources.

### Never use `count` for named resources

Never use `count = length(var.items)` to create N resources from a list. Removing a middle item renumbers the list and Terraform destroys/recreates everything after it.

### `for` expressions are for `locals` only

Use `for` expressions inside `locals {}` to prepare data for `for_each`. Never in `main.tf`, never in a resource argument directly.

### The five `for` expression patterns

1. **Filter** — drop entries that don't meet a condition:

   ```hcl
   enabled_tiers = { for k, v in var.tiers : k => v if v.enabled }
   ```

2. **Transform** — reshape each item (e.g., compute a name from a key).

3. **List to map** — convert a list into a keyed map.

4. **Flatten** — the canonical pattern for nested structures. Collapse a map-of-lists into a flat map so `for_each` can consume it:

   ```hcl
   flat_role_assignments = {
     for pair in flatten([
       for role, principals in var.role_assignments : [
         for principal in principals : {
           key          = "${role}/${principal}"
           role_name    = role
           principal_id = principal
         }
       ]
     ]) : pair.key => pair
   }
   ```

5. **Enrichment** — merge computed fields into existing data:

   ```hcl
   enriched_subnets = {
     for k, v in var.subnets : k => merge(v, {
       resource_group_name = local.resource_group_name
     })
   }
   ```

### Dynamic blocks

- For conditional nested blocks, use `dynamic` with `for_each = condition ? [1] : []`:

  ```hcl
  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }
  ```

- For iterating a list in a dynamic block, wrap in `toset()` for stable plans — adding or removing entries won't renumber the others.

---

## 7. Functions

### Safe access and fallback

- `try(expr, fallback)` — safely read optional attributes and possibly-malformed data. Do not build long conditional chains for the same purpose.
- `coalesce(a, b, c)` — pick the first non-null, non-empty value. Do not nest ternaries.
- `can(expr)` — test whether an expression would succeed. Use inside `validation` blocks.
- `one(resource.x[*].attr)` — extract an attribute from a 0-or-1 resource. Do not use `resource.x[0].attr`.
- `lookup(map, key, default)` — read a possibly-missing key. Do not use bracket access for possibly-missing keys.

### String handling

- `templatefile("${path.module}/templates/<n>.tftpl", { ... })` — for multi-line content, scripts, config files. Do not build multi-line strings with `format()` or heredocs.
- `lower()`, `replace()`, `substr()` — normalize user-provided names before using in resource names.
- `trimspace(file(...))` — when reading SSH public keys. Azure rejects trailing newlines.

### Structured content

- `jsonencode(...)` — Azure Policy rules, app settings blobs. Never hand-write JSON.
- `yamlencode(...)` — Helm values, Kubernetes manifests. Never hand-write YAML.
- `base64encode(jsonencode({...}))` — App Service app settings with structured payloads.
- **Never use `base64encode()` to store secrets.** Use Key Vault references (`@Microsoft.KeyVault(...)`).

### Hashing

- `substr(sha256(...), 0, 8)` — deterministic unique suffix for globally-unique Azure names.
- `md5()` — change detection tags only, never security.

### File system

- `file("${path.module}/...")` — text files (scripts, JSON, YAML, SQL).
- `filebase64("${path.module}/...")` — binary files (certificates, images).
- Always anchor paths on `path.module`. Never use `path.root`, `path.cwd`, or bare relative paths.
- Always use forward slashes, even on Windows.
- `fileset("${path.module}/<dir>", "*.json")` with `for_each` — policy-as-files pattern. Adding a policy means adding a file, no code change needed.
- `filesha256(...)` — content fingerprint for change-detection tags.
- Do not call `file()` on multi-megabyte files.

### Type conversion

- Rely on implicit coercion only for string interpolation (`"${var.port}"` is fine).
- Use explicit `tostring()`, `tonumber()`, `tobool()`, `toset()` everywhere else.
- `tobool()` accepts only `"true"` and `"false"`. For `"yes"/"no"` inputs, compare strings directly.

### Does not exist

- `clamp()` — use `max(min_val, min(max_val, value))`.

---

## 8. Modules — structure and API

### Directory layout

```
modules/<n>/
├── terraform.tf    # required_version and required_providers — no backend, no provider
├── variables.tf    # input declarations
├── locals.tf       # computed values
├── main.tf         # data sources, resources, nested module calls
└── outputs.tf      # outputs
```

### Module API is a versioned contract

Rename or remove a variable = breaking change for every caller.

### Required vs. optional inputs

- Required: only what Terraform cannot infer — `name`, `resource_group_name`, `location`.
- Everything else: optional with a sensible default.

A caller using the simple case should supply ~3 arguments. A caller exercising full control should have every knob available.

*Why: if every attribute is required, every caller writes 40 lines of boilerplate for the same defaults. The module's purpose is to provide sane defaults.*

### Calling modules

- `source` is the only required meta-argument.
- Source paths:
  - Local (`./modules/<n>`) — for modules in the same repo.
  - Git with pinned `?ref=` to a tag or SHA — for shared modules. **Never a branch.**
  - Terraform Registry — for third-party modules.
- Run `terraform init` after adding a new `module` block.
- Conditional modules: `count = var.enabled ? 1 : 0`. Reference outputs with `one(module.x[*].attr)`.
- Parameterized modules: `for_each = var.<map>`. Outputs are maps keyed by input key.

### What callers cannot control

- Provider configuration inside the module (except via `configuration_aliases`).
- Internal resources, data sources, or locals.
- Any value not declared as an output.

### Wiring modules together

- Outputs → inputs creates implicit dependencies. Terraform orders automatically.
- Dependencies flow one direction. No circular references.
- You cannot reach `module.X.azurerm_<type>.<n>.attr` from outside — only declared outputs.

---

## 9. Modules — boundaries and design

### The three guidelines

1. **More than one resource.** Single-resource modules rarely add value. Narrow exceptions: shared validation, org standards, compatibility shims.

2. **Same lifecycle.** Resources in a module should change at the same rate, for the same reasons, ideally by the same team.

3. **Same RBAC grouping.** Role assignments live in the module whose resource they protect.

   | Assignment scope | Module |
   | --- | --- |
   | Specific resource | That resource's module |
   | Resource group | Resource group module, or dedicated access module |
   | Subscription | Dedicated governance module |

*Why (lifecycle): a module that combines a VNet (changes rarely) with an AKS cluster (upgrades often) runs a full plan against both every time either changes. The blast radius of any mistake is the entire module.*

*Why (RBAC): when role assignments live with the resource they protect, destroying the resource destroys its access control atomically. Separated, you risk orphaned permissions and drift.*

### Six-question checklist

Before creating or reviewing a module:

1. Does it manage more than one resource?
2. Do all resources change for the same reason?
3. Are all resources owned by the same team?
4. Do all RBAC assignments protect resources in this module?
5. Can you describe the module's purpose in one sentence?
6. Would a caller think of these resources as one logical unit?

Any "no" means reconsider.

### `azuread` resources

Typically belong in a **separate identity module** — different ownership (identity/security teams), different lifecycle (compliance reviews, may outlive infrastructure).

Exception: when an AAD resource is tightly coupled to one specific infra resource and shares its lifecycle exactly — e.g., an AAD group created specifically as the admin group for one AKS cluster.

### `azapi` resources

When `azapi` extends an `azurerm` resource:

- The `azapi` resource lives in the **same module** as the `azurerm` resource. Same lifecycle, meaningless without it.
- Include a comment explaining what it does and why `azurerm` isn't sufficient, with a link to the tracking issue.
- Include `depends_on` referencing the underlying `azurerm` resource.

```hcl
# azapi: Enable node OS auto-upgrade channel — not yet in azurerm.
# Remove when azurerm adds native support.
# Ref: https://github.com/hashicorp/terraform-provider-azurerm/issues/XXXXX
resource "azapi_update_resource" "node_os_upgrade_channel" {
  type        = "Microsoft.ContainerService/managedClusters@2023-10-01"
  resource_id = azurerm_kubernetes_cluster.this.id
  body        = jsonencode({ ... })
  depends_on  = [azurerm_kubernetes_cluster.this]
}
```

---

## 10. Providers and versions

### Module `terraform.tf`

- `required_version` — permissive (e.g., `>= 1.5.0`) so callers on older Terraform can still consume.
- `required_providers` — open-ended within a major version (`>= 4.61, < 5.0`).
- No `backend` block. Ever.
- No `provider` block. Providers are inherited from the caller.

*Why (open-ended constraints): pessimistic constraints (`~> 4.61`) pin every caller to 4.61.x. If someone's root config needs 4.80 for another module, they can't use yours without forking. Open-ended says "I work with any 4.x" and lets callers choose.*

### Root `terraform.tf`

- `required_version` — strict (e.g., `>= 1.7.0`).
- `required_providers` — tight (`~> 4.61` pins minor, allows patch).
- `backend` block — required for team and CI use.
- `provider` blocks — here, or in a dedicated `providers.tf`.

### Provider inheritance

When root configures a provider, modules receive it automatically. No explicit pass-through for the default provider.

### Multi-provider modules

When a module works with multiple provider instances (multi-region, multi-subscription), declare `configuration_aliases` in the module and pass aliased providers via `providers = { ... }` on the `module` call.

```hcl
# Module terraform.tf
required_providers {
  azurerm = {
    source                = "hashicorp/azurerm"
    version               = ">= 4.61, < 5.0"
    configuration_aliases = [azurerm.primary, azurerm.secondary]
  }
}

# Root main.tf
module "replication" {
  source = "./modules/multi_region"
  providers = {
    azurerm.primary   = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }
}
```

---

## 11. Backends and state

### Azure backend

Use the `azurerm` backend for team and CI state. Benefits: locking via blob leases, RBAC, durability.

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "stterraformstate001"
  container_name       = "tfstate"
  key                  = "<project>/<environment>/terraform.tfstate"
}
```

### Backend rules

- Literal values only — backend blocks cannot reference variables or locals. Use `-backend-config=<file>` at `init` time for per-environment values.
- Key convention: `<project>/<environment>/terraform.tfstate`.
- Never define a backend in a module. Only in root.

---

## 12. Naming conventions

### Modules

| Context | Convention | Example |
| --- | --- | --- |
| Internal team modules | `azure_<resource>` | `azure_key_vault` |
| Published/shared | `terraform-azurerm-<resource>` | `terraform-azurerm-storage-account` |

### Resources within a module

| Situation | Convention |
| --- | --- |
| The module's primary resource | Name it `this` — `resource "azurerm_key_vault" "this"` |
| Multiple distinct resources of the same type | Descriptive names — `"azurerm_private_endpoint" "blob"`, `"file"` |

*Why (`this`): it's the standard across HashiCorp's official modules and well-maintained community modules. `this` signals "this is the main thing this module creates."*

### tfvars loading order

Lowest to highest precedence:

1. `default` in `variables.tf`
2. `terraform.tfvars`
3. `*.auto.tfvars` (alphabetical order)
4. `-var-file=<file>`
5. `-var 'name=value'`

### What to commit

- `terraform.tfvars` — yes, for non-sensitive defaults all developers share.
- `*.auto.tfvars` with personal or sensitive values — never. Add to `.gitignore`.
- Secrets — never in any `.tfvars`. Use `TF_VAR_<n>` environment variables or `-var` in CI.

### Multi-environment layout

```
environments/
  dev/
    main.tf
    terraform.tf
    terraform.tfvars
  prod/
    main.tf
    terraform.tf
    terraform.tfvars
modules/
  azure_<resource>/
    ...
```

Each environment directory is a separate working directory.

---

## 13. Security defaults

Module defaults encode the organization's baseline security posture. Callers who need a less-secure option must opt in explicitly.

| Attribute | Secure default |
| --- | --- |
| `public_network_access_enabled` | `false` |
| `purge_protection_enabled` (Key Vault) | `true` |
| `soft_delete_retention_days` (Key Vault) | `90` (the max) |
| `enable_https_traffic_only` (Storage) | `true` |
| `min_tls_version` | `"TLS1_2"` |
| `oidc_issuer_enabled` (AKS) | `true` |
| `workload_identity_enabled` (AKS) | `true` |
| Network ACL `default_action` when public access off | `"Deny"` |

### Other security rules

- Never commit secrets in `.tfvars` files.
- Never put secret string literals in `locals`.
- Never output secrets when outputting an ID and letting consumers fetch from Azure would work.
- `sensitive = true` is display-only. Protect state files via backend RBAC.
- `base64encode()` is not encryption. Use Key Vault references for secrets in app settings.

---

## 14. Anti-patterns

### File organization

- Mixing block types in one file (the "everything" file).
- Splitting `main.tf` by lifecycle (`create.tf`/`update.tf`) or team ownership.

### Variables

- Missing `type` or `description`.
- `type = any`.
- `sensitive = true` on a whole object variable when only one attribute is secret.
- Using `list(object)` with `for_each` when a `map(object)` with stable keys would work.

### Locals

- Generic names (`config`, `data`, `values`).
- Business logic beyond infrastructure computation.
- Secrets as string literals.

### Outputs

- One output per attribute (`kv_id`, `kv_name`, `kv_uri`) instead of one structured `key_vault` object.
- Output shape that differs from input shape.
- `value = azurerm_<resource>.this` in shared/published modules.
- Outputting secrets when outputting an ID would work.
- Sensitive root output referencing a sensitive module output without also being sensitive.

### Resources

- Computation logic inline in resource arguments.
- Hardcoded resource names or locations.
- `depends_on` when references already create the dependency.
- `resource.x[0].attr` on a 0-or-1 resource — use `one()`.

### Loops

- `count` for resources with meaningful names or from lists that may lose middle entries.
- `for_each` on a list without `toset()`.
- `for` expressions outside `locals`.

### Functions

- Hand-written JSON or YAML string literals.
- Bare `regex()` in validation (use `can(regex(...))`).
- Bracket access on a possibly-missing map key (use `lookup`).
- Multi-line strings with `format()` when `templatefile()` would be clearer.
- Absolute filesystem paths or bare relative paths (always `path.module`).
- `clamp()` — doesn't exist.

### Modules

- Single-resource modules without a specific reason.
- Combining resources with different lifecycles or team ownership.
- Role assignments in a different module from the resource they protect.
- `azapi` resources without a comment and link.
- Modules with a `backend` or `provider` block.
- Pessimistic version constraints (`~> 4.61`) in modules.
- Git source without a pinned `?ref=` to a tag or SHA.
- Circular module references.
- Treating `sensitive = true` as access control.

---

## 15. Open questions

Questions raised during the learning lessons that haven't been resolved. To be answered with the team and folded back into the rules above.

- Does the team use `terraform.tfvars` for shared defaults, or always `.auto.tfvars`? Which is gitignored?
- Is 8 characters of `sha256` the standard unique-suffix length?
- `.tmpl` vs `.tftpl` for template files? (HashiCorp recommends `.tftpl`.)
- Exact `required_version` floors for root (`>= 1.7.0`?) and modules (`>= 1.5.0`?).
- Exact provider version floors the team targets.
- Tag convention for Git module sources — semver (`v1.2.0`), pin to SHA, or both?
- When to use `configuration_aliases` vs. calling a module once per region from root?
- Standard structure for the identity module when `azuread` resources are separated out — per-app or per-environment?
- How to split `main.tf` — exact line count, or judgment call?
- One `terraform.tf` or separate `providers.tf`?

---

## How this file is maintained

This file is a living document. Update it when:

- Team conventions change.
- A code review catches a pattern not yet documented.
- A production incident reveals a rule that should have existed.
- Terraform or the `azurerm` provider releases a feature that changes best practice.

A stale `AGENTS.md` is worse than none — the AI and humans will follow outdated guidance. If you're unsure whether a rule still applies, ask in review rather than silently ignoring it.