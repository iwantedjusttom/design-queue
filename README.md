# design-queue

The **DESIGN agent (Agent A)** in a two-agent `design → build` pipeline where work is tracked as **GitHub Issues**.

This skill governs everything **before** any code: talking a feature through, sorting it for safe parallel builds (foundation-first), producing the schema design and a mockup, and — when it's ready — filing it as a GitHub issue Tom moves into the Ready column. It never writes code and never creates branches.

The hopper is **GitHub Issues**, so it syncs to every machine and is backed up automatically; nothing lives in a local folder.

## Triggers

- "design the next feature", "spec this out", "get this ready to build"
- "design the schema for X", "add this to the hopper"
- milestone / roadmap planning: "build me a roadmap", "where are we", "am I on track"

Any design/spec/planning work on a GitHub-Issues pipeline.

## Companion

**build-loop** (Agent B) builds the Ready-column issues this skill produces. Designing, speccing, sorting for parallel safety, and roadmap/milestones live here — not in build-loop.

## Install

```powershell
git clone https://github.com/iwantedjusttom/design-queue.git
New-Item -ItemType Junction -Path "$HOME\.claude\skills\design-queue" -Target "<path>\design-queue"
```
