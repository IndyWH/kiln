---
name: ai-bug-reports-folder
description: "Owner's idea, 4 Nov 2026: a repo folder ai-bug-reports with one verified report per bug found in other projects, named project first; not created yet"
metadata:
  node_type: memory
  type: project
  modified: 2026-11-05T08:06:56.944Z
---

On 4 Nov 2026 the owner proposed a repo folder `ai-bug-reports/`: one report for each bug found. The file name starts with the project (Gentoo, Rust and so on), followed by the bug. Each report starts with mlrig's specs, then describes the bug. The owner agreed the conditions below on 4 Nov 2026, and said the folder is only for developers interested in Kiln who come to the repo to read it. It is not an outreach channel. Created on 5 Nov 2026, with three reports, none sent.

**Why:** Kiln's measuring finds real faults in other projects, and a written record makes them useful to others.

**How to apply:** suggested file names such as `gentoo-rust-recipe-drops-ndebug.md`. Suggested rule: a report goes in only after the bug is reproduced with a clean test and checked against the project's tracker, on an unmodified recipe where possible, and it says what was not checked. Specs stay short, with no serial numbers or IDs. Each report has a status line. The folder only records: Claude never files anything with a project. Gentoo's Council bans AI-made contributions, and other projects have their own rules, such as GCC and LLVM, so sending a report is the owner's decision, in their own words, under that project's rules. Bugs in Kiln's own work go in HANDOVER.md or `lessons/`, not here. Failed overfiring goes in [[kiln-stories-folder]]. First candidates: Gentoo's Rust recipe dropping `-DNDEBUG`, once proved, and the PyTorch and Kineto mismatch noted in HANDOVER.md.
