---
page_title: "Template sync and TFPS_TEMPLATE_SYNC_TOKEN"
description: |-
  How the managed file set is kept in step with the template, and how to
  mint the personal access token that lets a sync update workflow files.
---

<!-- Not a MANAGED file: this page ships with a new copy of the template but is
     never synced afterwards. Edit it or delete it as you see fit. -->

# Template sync and `TFPS_TEMPLATE_SYNC_TOKEN`

> **Template note:** this page is for whoever *maintains* a repo created from
> the template, not for people consuming the published provider. If you
> publish to the Terraform Registry, delete `docs/guides/template-sync.md`
> from your copy — registry guides are end-user documentation.

`.github/workflows/template-sync.yml` keeps the managed file set — `.template/**`,
`.github/workflows/**`, and a fixed list of root files — in step with
[the template](https://github.com/MarkDomansky/TEMPLATE-terraform-provider-YOURPROVIDER).
It runs in two modes:

| Mode | Trigger | What it does |
|---|---|---|
| Monthly check | schedule, 1st of the month | Opens or refreshes a **"Template updates available"** issue. Never pushes. |
| Manual sync | `workflow_dispatch` | Force-pushes a `template-sync` branch and opens a PR into `beta` (or your default branch). |

## Why a token is needed

GitHub forbids the default `GITHUB_TOKEN` from pushing changes to
`.github/workflows/**`. That restriction is on *writing* only — the sync always
**detects** workflow drift, with or without a token, so nothing is ever silently
skipped. Without the token you get:

- a **warning annotation** on the workflow run naming each file it could not apply,
- the same list as a `> [!WARNING]` block in the sync PR body,
- and, when workflow files are the *only* thing out of date, the tracking issue
  stays **open** with that warning rather than being closed as "up to date".

You then copy those files from the template by hand. Adding the token removes
that manual step, and has a second benefit: PRs opened with the default token
do not trigger CI (GitHub ignores events created by `GITHUB_TOKEN`), so sync PRs
show no checks until you close and reopen them.

## Creating the token

Use one fine-grained PAT named `TFPS_TEMPLATE_SYNC_TOKEN`, scoped to a
**specific list of repositories: the repos created from this template**. Do not
grant "All repositories" — this token can rewrite workflow files, which is
effectively arbitrary CI execution in every repo it can reach.

1. Go to **Settings → Developer settings → Personal access tokens → Fine-grained
   tokens → Generate new token** (<https://github.com/settings/personal-access-tokens/new>).
2. Name it `TFPS_TEMPLATE_SYNC_TOKEN`.
3. **Repository access → Only select repositories**, then select every repo made
   from this template (see below).
4. Grant these repository permissions, and nothing else:

   | Permission | Access | Needed for |
   |---|---|---|
   | Contents | Read and write | pushing the `template-sync` branch |
   | Workflows | Read and write | updating `.github/workflows/**` |
   | Pull requests | Read and write | opening and refreshing the sync PR |
   | Issues | Read and write | the "Template updates available" tracking issue |
   | Metadata | Read | mandatory, added automatically |

   Add **Secrets: Read and write** only if you intend to install the token into
   other repos with `gh secret set` using the token itself.

To list the repositories that were created from the template:

```bash
gh api graphql -f query='
  query($owner: String!) {
    repositoryOwner(login: $owner) {
      repositories(first: 100, ownerAffiliations: OWNER) {
        nodes { nameWithOwner templateRepository { nameWithOwner } }
      }
    }
  }' -F owner=YOUR_GITHUB_USERNAME \
  --jq '.data.repositoryOwner.repositories.nodes[]
        | select(.templateRepository.nameWithOwner == "MarkDomansky/TEMPLATE-terraform-provider-YOURPROVIDER")
        | .nameWithOwner'
```

`templateRepository` is only populated for repos created with **Use this
template**. Copies made by cloning and pushing, or by forking, will not appear —
add those to the list by hand.

## Installing it

Add the token as a repository secret named `TFPS_TEMPLATE_SYNC_TOKEN` in **each**
repo created from the template (Settings → Secrets and variables → Actions), or:

```bash
gh secret set TFPS_TEMPLATE_SYNC_TOKEN --repo OWNER/REPO
```

`gh secret set` reads the value from stdin when you omit `--body`, so the token
never lands in your shell history.

The workflow falls back to `GITHUB_TOKEN` when the secret is absent, so a repo
without it still syncs everything except workflow files.

## Keeping it current

- **Adding a copy:** a new repo created from the template is *not* covered by an
  existing token — edit the token's repository list to include it, and add the
  secret to the new repo. Until you do, its syncs warn about workflow drift
  instead of applying it.
- **Expiry:** fine-grained tokens must carry an expiration (366 days maximum).
  When it lapses the sync degrades to the no-token behaviour above — it warns,
  it does not fail silently. Regenerate and re-run `gh secret set` for each repo.
- **Rotation:** revoking the token is safe at any time; nothing else depends on it.

## Related

- [Writing resources](writing-resources.md) — the resource authoring contract.
- `SETUP.md` in the repo root — the full one-time setup checklist for a new copy.
