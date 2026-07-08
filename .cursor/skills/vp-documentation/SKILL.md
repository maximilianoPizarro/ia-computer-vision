---
name: vp-documentation
description: >-
  Validated Patterns documentation guidelines for ia-computer-vision. Use when
  writing or editing AsciiDoc (.adoc) files, README.md, SUPPORT.md, docs/ folder
  content, GitHub Pages, or any user-facing documentation for this pattern.
  Follows Red Hat Supplementary Style Guide and VP contributor's guide.
---

# VP Documentation -- ia-computer-vision

## Style guides (mandatory)

1. **Primary**: [Red Hat Supplementary Style Guide](https://redhat-documentation.github.io/supplementary-style-guide/)
2. **VP-specific**: [VP Contributor's Guide](https://validatedpatterns.io/contribute/contribute-to-docs/)
3. **General**: IBM Style (via Red Hat)

## Language rules

- **Active voice**, second person ("you")
- **No contractions** ("do not" instead of "don't")
- **Present tense** ("The operator installs" not "The operator will install")
- **Conscious language** (use inclusive terminology)
- **Gender neutral** ("they" as singular pronoun)
- **Sentence-style capitalization** in all titles and headings
- **Gerund form** for procedure titles ("Deploying the pattern", "Configuring secrets")
- **Noun phrase** for concept/reference titles ("Architecture overview", "Cluster sizing requirements")

## Product names (first use vs subsequent)

| First use | Subsequent |
|-----------|-----------|
| Red Hat OpenShift Container Platform (OCP) | OCP or OpenShift |
| Red Hat Advanced Cluster Management (RHACM) | RHACM or ACM |
| Red Hat OpenShift GitOps | OpenShift GitOps |
| Red Hat Developer Hub (RHDH) | RHDH or Developer Hub |
| Red Hat OpenShift AI (RHOAI) | RHOAI or OpenShift AI |
| Red Hat Advanced Cluster Security (RHACS) | RHACS or ACS |
| Red Hat Build of Keycloak (RHBK) | RHBK |
| Red Hat Connectivity Link (RHCL) | RHCL or Connectivity Link |
| Red Hat Quay | Quay |
| Red Hat Trusted Artifact Signer (RHTAS) | RHTAS |

## AsciiDoc conventions

### Content type attributes (required in every .adoc file)
```asciidoc
:_content-type: ASSEMBLY     // or CONCEPT, PROCEDURE, REFERENCE
```

### Code blocks
```asciidoc
[source,terminal]
----
$ oc get pods -n neuroface
----

[source,yaml]
----
apiVersion: v1
kind: Namespace
metadata:
  name: neuroface
----
```

### User-replaced values
Use `<variable_name>` syntax:
```asciidoc
$ oc login --token=<token> --server=https://api.<cluster_domain>:6443
```

### Admonitions
```asciidoc
[NOTE]
====
Additional context that is helpful but not critical.
====

[IMPORTANT]
====
Information the user must know to avoid problems.
====

[WARNING]
====
Actions that can cause data loss or security issues.
====

[TIP]
====
Optional optimization or shortcut.
====
```

Do NOT use CAUTION (Red Hat style guide does not use it).

## docs/ folder structure

```
docs/
├── config.yaml                    # Hugo config
├── Makefile                       # `make serve` with podman
├── content/
│   └── patterns/
│       └── ia-computer-vision/
│           ├── _index.adoc        # ASSEMBLY: pattern overview
│           ├── getting-started.adoc   # ASSEMBLY: deploy procedure
│           ├── pattern-cr-guide.adoc  # REFERENCE: Pattern CR per topology (Scenarios A–E)
│           ├── cluster-sizing.adoc    # ASSEMBLY: sizing tables
│           ├── architecture.adoc      # ASSEMBLY: topology
│           └── ideas-for-customization.adoc  # CONCEPT
├── modules/
│   └── ia-computer-vision/
│       ├── metadata-ia-computer-vision.adoc   # attributes from pattern-metadata.yaml
│       ├── iacv-about.adoc                    # CONCEPT
│       └── iacv-architecture.adoc             # CONCEPT
├── static/
│   └── images/
│       └── ia-computer-vision/
└── .wordlist.txt
```

### Assembly file template (_index.adoc)
```asciidoc
---
title: AI Computer Vision
date: 2026-06-24
tier: sandbox
summary: Multi-cluster AI Computer Vision at the Edge with hub-spoke GitOps.
rh_products:
- Red Hat OpenShift Container Platform
- Red Hat Advanced Cluster Management
- Red Hat OpenShift AI
industries:
- Manufacturing
- Technology
focus_areas:
- AI/ML
- DevSecOps
aliases: /ia-computer-vision/
pattern_logo: ia-computer-vision.png
links:
  github: https://github.com/maximilianoPizarro/ia-computer-vision
  install: getting-started
---
:toc:
:imagesdir: /images
:_content-type: ASSEMBLY
include::modules/comm-attributes.adoc[]

include::modules/ia-computer-vision/iacv-about.adoc[leveloffset=+1]

include::modules/ia-computer-vision/iacv-architecture.adoc[leveloffset=+1]
```

### Module file template
```asciidoc
:_content-type: CONCEPT
[id="iacv-about_{context}"]
= About the AI Computer Vision pattern

Enterprise teams need secure multi-cluster AI inference...
```

## README.md structure

```markdown
# AI Computer Vision

Validated Patterns implementation of multi-cluster AI Computer Vision at the Edge.

## Why this pattern?
[Business problem statement]

## Architecture at a glance
[Mermaid diagram: hub/east/west topology]

## What is included
[Component table: ACM, Vault, RHDH, GitLab, etc.]

## Quick start
[3-step install: hub-only CPU (default) or hub + spokes; link to pattern-cr-guide]

## Pattern CR examples
[`examples/pattern-cr/` — one YAML per topology; pattern-cr-guide.adoc is the decision table]

## Cluster sizing
[Table with m6a.2xlarge specs]

## Verification
[Commands to verify install]

## Documentation
[Link to GitHub Pages]

## Support
Sandbox tier. See SUPPORT.md.

## License
Apache-2.0
```

## Key constraints

- Do NOT submit documentation to validatedpatterns/docs repo yet
- GitHub Pages hosted from this repo's `docs/` folder
- All images in `docs/static/images/ia-computer-vision/`
- Maintainer: Maximiliano Pizarro (mapizarr@redhat.com)

## Lessons learned from a documentation audit against a live cluster (Jul 1, 2026)

### `:_content-type:` must go AFTER the closing `---` of Hugo front matter, never inside it
Hugo's front matter is a YAML block between `---` delimiters; everything inside it is parsed as YAML and stripped before the AsciiDoc processor ever sees the content. Putting `:_content-type: REFERENCE` as a line inside the front matter (mixed with `title:`, `date:`, `summary:`) is syntactically harmless YAML but has **zero effect** — Asciidoctor never processes it. Always place `:_content-type:` (and other AsciiDoc document attributes like `:toc:`, `:imagesdir:`) on their own line(s) immediately after the closing `---`, before the `= Title` line. Verify with: does the string appear anywhere in the rendered `public/.../index.html`? It should not (attributes are metadata, not visible text) — but check the *page actually builds and gets the right weight/ordering* as the real signal.

### Verify every command in a "getting started" / installation guide against a real cluster before trusting it
Running each documented verification command for real turned up several that would mislead or hard-fail anyone following the guide on a fresh install:
- **Stale "expected output" application lists.** `getting-started.adoc`'s Step 1 (hub) and the east-spoke verification section both drifted significantly from the actual `clusterGroup.applications` in `values-hub.yaml`/`values-east.yaml` — missing several real apps, and including apps that are commented out (disabled) by default (`acs-init-bundle-sync`, `acs-secured-cluster`). Cross-check any such table against `python3 -c "import yaml; print(sorted(yaml.safe_load(open('values-hub.yaml'))['clusterGroup']['applications'].keys()))"` (or the live `oc get application -n vp-gitops`), not against memory of what used to be there.
- **Route names are not fixed strings.** Operator-managed routes get generated names: RHDH's route is `backstage-developer-hub` (not `backstage`), Cluster Observability Operator's Grafana route is `grafana-route` (not `grafana`). GitLab's webservice route carries a random suffix (`gitlab-webservice-default-<hash>`) — look it up by label (`oc get route -n gitlab-system -l app=webservice`) instead of guessing a name.
- **A step assumed an optional component (RHACS) is always deployed.** RHACS is disabled by default in this pattern (commented out to save resources). A verification step that unconditionally checks `oc get central -n stackrox` needs a note explaining it is conditional, or it looks like a broken install to anyone doing a default deployment.
- **"Expected output" for an OIDC-protected route was `200`, but the real behavior is a `302` redirect to Keycloak.** When a route has an `AuthPolicy` with OIDC, an unauthenticated `curl` should be documented as returning `302` (with an explanation of what that proves), not `200` — otherwise the guide's own success criteria contradicts reality and users think something is broken when it is actually working correctly.

**Practical audit technique**: extract every `[source,bash]` block with an `oc get`/`curl` command from a doc, run it against a real (or representative) cluster, and diff the real output against the doc's `.Expected output` block. Do this any time the underlying chart's application list, route names, or AuthPolicy coverage changes — documentation staleness on exactly these three axes is where this pattern's docs kept drifting.

## Documenting vendor/sandbox-specific overlays generically (Jul 2026)

`values-hub-rhpds.yaml` and its sizing/troubleshooting entries name the sandbox vendor explicitly (established prior art in `cluster-sizing.adoc` and `troubleshooting.adoc` — do not rewrite those, they document real, already-verified debugging against that specific environment). When adding **new** documentation about the underlying *scenario* that overlay solves (a cluster with a base set of operators pre-installed before you get cluster-admin access, a single all-in-one node, a pre-existing SSO instance claiming the default hostname), write the prose generically — describe the situation and its symptoms, not the vendor name — even though the concrete file you point readers at is still literally named `values-hub-rhpds.yaml` (do not invent a fictitious filename; renaming it is a much larger, riskier refactor than a documentation task and out of scope for "add documentation" requests). See `ideas-for-customization.adoc`, "Configuring GPU inference on a cluster with pre-installed operators", for the pattern to follow.

## Verify every cross-reference anchor before committing, not just the target file's syntax

`xref:_id[...]` (same-page) and `link:../other-page/#_id[...]` (cross-page) both depend on Asciidoctor's auto-generated heading IDs, which are **not** simply "lowercase with underscores" — verify them by actually rendering, don't guess:

```bash
$ python3 -c "
content = open('the-file.adoc').read()
parts = content.split('---', 2)   # strip Hugo front matter -- raw asciidoctor CLI errors on it otherwise ('level 0 sections can only be used when doctype is book')
body = parts[2] if len(parts) == 3 else content
open('_test.adoc', 'w').write(body)
"
$ asciidoctor -o _test.html _test.adoc
$ grep -o 'id="_your_guessed_id"' _test.html   # confirms the heading actually generates that id
$ grep -o 'href="#_your_guessed_id"' _test.html  # confirms your xref/link resolved to it
$ rm -f _test.adoc _test.html   # never commit these
```

Do this for every file you add a `[[custom_anchor]]` or heading-derived cross-reference to, and for every file whose headings you edited (a reworded heading changes its auto-generated ID and silently breaks any existing xref pointing at the old one).

## Showroom lab guide (external repo)

Antora content lives in https://github.com/maximilianoPizarro/showroom-ia-computer-vision (not this repo). Module numbering:

| Module | File | Topic |
|--------|------|-------|
| 09 | `09-maas-native-rhoai.adoc` | Native RHOAI 3.4 MaaS, Gen AI Studio API keys |
| 10 | `10-argocd-mcp-lightspeed.adoc` | Argo CD MCP, OpenShift Lightspeed, multi-cluster GitOps |

Activity overview diagrams (PatternFly styling, Red Hat product badges): `content/modules/ROOT/images/m09-maas-native-activity.svg`, `m10-argocd-mcp-activity.svg`. Deploy by pushing to the showroom Git repo; the hub `showroom` chart clones `showroom.content.repoUrl` at sync time.

Document new terminal helpers in `docs/content/patterns/ia-computer-vision/workshop.adoc` whenever adding functions to `charts/all/showroom/templates/showroom.yaml`.
