# omarchy4mac: Claude Code

See `AGENTS.md`; this block is identical in every agent's instructions.

<!-- issue-bundling:start -->
## Issue review and bundling (standing rule, set 2026-11-15, GH #1473)

Tyler's standing permission to every agent, no asking:

1. **Before any coding job**, read the open issues once (`gh issue list`). Bundle related ones (same files, view or feature) into one brief and one PR that closes them all.
2. **Close** issues that are shipped, duplicated, superseded or dead, each with a one-line comment saying why and linking the PR or replacement.
3. **Label clusters** so the next job can pick up a whole bundle.
4. **Never close** anything Tyler filed in the last 24 hours unless it shipped or he replaced it. **Never touch #1363.**

One pass at the start of each job, no polling. Source: tyler-os `docs/rules/issue-bundling.md`.
<!-- issue-bundling:end -->
