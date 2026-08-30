# Repo rules (for humans and AI assistants)

* This repo is built from the TEMPLATE-terraform-provider-YOURPROVIDER
  template. Everything under `.template/` is owned by the template and updated
  via template-sync PRs — never edit it — as are the root files carrying a
  "MANAGED FILE" header (the workflows, `go.mod`/`main.go`/`main_test.go`,
  `.releaserc.cjs` — a shim requiring `.template/release/releaserc.cjs` —
  `.gitignore`, and `docs/guides/writing-resources.md`). Everything else under
  `provider/`, `docs/`, `examples/`, and `tests/e2e/` is fork-owned.
* Resources are folders of PowerShell scripts + resource.tfps.json under
  `provider/resources/`; the authoring contract is in
  docs/guides/writing-resources.md. Scripts must not declare `param(...)`,
  must emit exactly one object, and must keep the error stream clean.
* Keep unit tests cross-platform (Windows/Linux/macOS, PowerShell 7).

## Commit messages decide the released version

Versions are **not** set by hand. `semantic-release` reads the commit messages
on the pushed branch and computes the next version
(`.github/workflows/release.yml`, configured by `.releaserc.cjs`). Never edit
a version string by hand and never create a `v*` tag manually — the release
workflow creates the tag itself, only after the install smoke test passes.

* Squash-merge PRs into `beta` (prereleases); merge `beta` into `main` with a
  REAL merge commit (never squash) for GA.
* Only `main` ever publishes the wiki (`wiki-sync.yml` asserts this in the
  job's `if:` as well as its trigger — do not relax either).
* **Exception, in the template repo itself:** there is no `beta` branch and no
  release. The template ships no installable provider, and forks consume it as
  a file copy from a ref (`template-sync.yml` checks out `main`), never as a
  versioned artifact — so a prerelease channel would have no consumer. Work
  lands as PRs into `main`; the `publish` job in `release.yml` is guarded off
  by repository name, so the pipeline still builds and smoke-tests here but
  never tags or uploads `terraform-provider-yourprovider` artifacts. The rules
  above are what forks inherit and are correct there.

## Engine dependency

The terraform-provider-powershell engine version is resolved at build time by
`.template/build/Update-Engine.ps1` from `provider/settings.tfps.json` (`"latest"` GA or an
exact pin). go.mod's require line is a baseline, not the truth — do not bump
it by hand; change `engine_version` instead.
