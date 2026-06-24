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
[3-step install for hub, east, west]

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
