---
page_title: "Writing resources"
description: |-
  The authoring reference: folder layout, the manifest format, and the
  PowerShell script contract.
---

<!-- MANAGED FILE - do not edit in your fork; owned by the template, deliberately published from docs/guides/. -->

# Writing resources

Every resource is a folder under `provider/resources/<name>/`; every data
source a folder under `provider/data-sources/<name>/`. The folder name (lowercase
letters, digits, underscores) becomes the Terraform type suffix:
`provider/resources/mailbox/` in a provider named `exchange` is
`resource "exchange_mailbox"`.

| File | Required | Purpose |
|---|---|---|
| `resource.tfps.json` | yes | Typed attribute declarations (below) |
| `create.ps1` | yes (resources) | Create the object; emit its state incl. `id` |
| `read.ps1` | yes | Refresh state; emit nothing if the object is gone |
| `update.ps1` | no | In-place update. **Its presence alone decides semantics**: without it, any config change replaces the object (delete+create) |
| `delete.ps1` | yes (resources) | Destroy the object (keep it idempotent) |
| `tests/*.Tests.ps1` | recommended | Pester unit tests via the ScriptUnit harness |

Data sources have only `datasource.tfps.json` + `read.ps1`.

## The manifest

```json
{
  "$schema": "https://json.schemastore.org/tfpowershell-resource.json",
  "version": 1,
  "description": "Manages an Exchange Online distribution group.",
  "timeout_seconds": 600,
  "attributes": {
    "name":         { "type": "string", "required": true, "requires_replace": true,
                      "description": "Group name; changing it recreates the group." },
    "hidden":       { "type": "bool", "optional": true, "default": false },
    "members":      { "type": "set",  "element_type": "string", "optional": true },
    "quota_mb":     { "type": "int",  "optional": true,
                      "validators": [ { "one_of": [10, 50, 100] } ] },
    "extra":        { "type": "json", "optional": true },
    "primary_smtp": { "type": "string", "computed": true },
    "access_token": { "type": "string", "computed": true, "sensitive": true }
  }
}
```

Parsing is **strict**: unknown keys anywhere are load errors (caught by
`go test ./...` and at provider start), so a typo can never be silently
ignored. The sole exception is `"$schema"`, which the engine accepts and
ignores.

Manifests are named `resource.tfps.json`, `datasource.tfps.json`,
`provider.tfps.json`, and `settings.tfps.json` — distinctive enough that
editors auto-associate the published JSON Schemas from
[SchemaStore](https://www.schemastore.org) by filename, giving you completion
and inline validation of every rule on this page. The `"$schema"` key above is
belt-and-braces: it keeps the association working if you rename a file or paste
a manifest somewhere else.

### Attribute fields

| Field | Rules |
|---|---|
| `type` | `string`, `bool`, `int`, `number`, `list`, `set`, `map`, `json`. `json` is a string attribute validated as a JSON object and decoded into a real object in `$InputData` — the escape hatch for nested data until structured types arrive. |
| `element_type` | Required for `list`/`set`/`map`: one of `string`, `bool`, `int`, `number`. |
| `required` / `optional` / `computed` | Exactly one must be true. Config attributes (required/optional) flow **into** scripts; computed attributes flow **out** of them. |
| `sensitive` | Redacts the value in CLI output. |
| `description` | Shown in docs and `terraform providers schema`. |
| `requires_replace` | Resource config attributes only: a change to this attribute always replaces the object. |
| `default` | Optional attributes only. Injected into `$InputData` when the practitioner leaves the attribute null. Note: state keeps `null` — the default is visible to your script, not to Terraform. |
| `validators` | `[{ "one_of": [ ... ] }]` for string/int/number config attributes. |
| `env` | Provider manifest only, optional string attributes: environment variable consulted when the attribute is unset. |

Every resource automatically gets a computed `id` — **do not declare it**.
Your `create.ps1` must emit it; the engine injects it back into `$InputData`
for read/update/delete, and `terraform import <addr> <id>` works out of the
box.

The same format describes the provider block (`provider/provider.tfps.json`):
attributes there may only be required/optional, and reach scripts as
`$global:ProviderData.Config.<name>` after the engine merges them with the
built-in provider attributes (startup_script, timeout, session_*, ... —
declaring one of those names is a load error).

## The script contract

The engine runs each script in a persistent PowerShell 7 process (the bundled
`pshost` sidecar), optionally inside a remote session (the built-in
`session_*` provider attributes give every derived provider WinRM/SSH/
PowerShell Direct support for free).

- `$InputData` — hashtable with every non-null config attribute, naturally
  typed (numbers, bools, arrays, hashtables; `json` attributes arrive
  decoded). On read/update/delete it also carries `id`.
- `$Action` — the current action name (`create`, `read`, ...).
- **Do not write your own `param(...)` block** — the engine injects one.
- **Emit exactly one object** to the success stream (a hashtable is
  idiomatic). Pipe unwanted cmdlet output to `Out-Null`; a second emitted
  object fails the operation.
- **Anything on the error stream fails the operation** — including
  non-terminating errors. Use `-ErrorAction SilentlyContinue` deliberately,
  never accidentally.
- Emitted keys matching **computed** attributes populate state (missing
  computed keys become `null`, with a warning in `TF_LOG` output). Keys
  matching config attributes are ignored — config always comes from the plan.
  Unknown keys are ignored with a warning.
- `read.ps1` emitting **nothing** (or no usable `id`) means "the object is
  gone": Terraform removes it from state and plans recreation. For data
  sources an empty emission just leaves every computed attribute null.
- Globals persist across all scripts in the run (the process is persistent):
  `provider/scripts/startup.ps1` typically authenticates and stashes state in
  your own `$global:...` variable; `shutdown.ps1` cleans up.

### Update vs. replace, precisely

1. Attribute marked `requires_replace` changed → **replace** (always).
2. Any other config attribute changed, no `update.ps1` → **replace**.
3. Any other config attribute changed, `update.ps1` exists → **update** —
   the script gets the planned config + `id`, and every computed attribute
   shows as "(known after apply)" in the plan.
4. Nothing changed → no call at all.

## Testing

- **Unit** (`provider/**/tests/*.Tests.ps1`): the ScriptUnit harness runs one
  script in-process with a fake `$InputData` and enforces the contract; Pester
  `Mock` works on any cmdlet the script calls, so no live system is needed.
  Run all: `pwsh ./.template/tests/unit/Invoke-UnitTests.ps1`.
- **E2E** (`tests/e2e/*.Tests.ps1`): real `terraform apply` against your
  compiled provider via dev_overrides (TFHarness). Gate suites that need live
  systems on `Get-E2ETestConfig`.
- `go test ./...` validates every manifest and script layout without running
  anything.
