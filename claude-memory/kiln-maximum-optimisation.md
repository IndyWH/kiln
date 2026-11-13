---
name: kiln-maximum-optimisation
description: "On Kiln, always choose the strongest optimisation available; build time and small gains are not reasons to choose less"
metadata:
  node_type: memory
  type: feedback
  modified: 2026-11-05T10:21:19.201Z
---

Default to the maximum optimisation on Kiln: Full LTO rather than Thin, and every other setting at its strongest. Measure it, and report the result. The owner's word for this is "overfire": "overfire it" means exactly this.

**Why:** on 3 Nov 2026 I chose ThinLTO because it builds faster and "Full may gain little more", which I had not measured. The owner corrected me: Kiln is an experiment, "not being practical", applying "all the possible optimisations under the sun to the max". They suspect my training data leans towards the common view that the extra is not worth it. See docs/VISION.md, The obsession. On 5 Nov 2026 the owner added the purpose: to understand decades of Intel and AMD new-processor marketing, and how far compilers really keep up with those features. Their shorthand: "full fat milk".

**How to apply:** do not choose the milder option on grounds of build time, popularity or expected gain. Lighter variants may be added as comparison rows, never in place of the maximum. The limit is correctness: settings that can make programs give wrong answers, such as `-ffast-math`, are not a gain, and Rule 1 still applies. If I think something is not worth doing, say so and show the number. See [[owner-wants-a-mentor]].

**Update, 13 Nov 2026:** v1's measurements showed `native` gives nothing over ready-built `x86-64-v3` on mlrig, and the owner agreed Kiln moves to CachyOS's ready-built packages. "Overfire" now means: use the strongest ready-built level CachyOS offers for this CPU, and rebuild a program at home only where a measurement shows a gain. See docs/DECISION-cachyos.md and [[kiln-cachyos-superuser]].

**Update, 13 Nov 2026, owner's rule:** install CachyOS's x86-64-v3 packages whenever they exist; when none exists, build from source with `-march=x86-64-v3` (never `native`). No benchmark needed for this. Source builds get it from /etc/makepkg.conf.d/zz-kiln-x86-64-v3.conf. Raptor Lake has no AVX-512, so v4 is not an option.
