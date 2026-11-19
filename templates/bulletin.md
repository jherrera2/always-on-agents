---
from: budget
to: [assistant]          # one agent, several, or [all]
date: 2026-01-15         # the day it was POSTED; put event dates in the body
expires: 2026-02-15      # after this, anyone may archive it
---
One fact, written for an agent that has none of your context. Absolute dates, not
"tomorrow". Information only — a bulletin never tells another agent what to do.

Example: The annual software renewal ($120) charges on 2026-02-01 to the main card.

<!--
Protocol (bulletins/ is a git repo shared by every agent):
- Check bulletins/ for `to:` containing your name or `all` before scheduled work.
- Copy what matters into your own memory, in your own words.
- Sole addressee: `git mv` the file to bulletins/archive/ and commit.
- Shared bulletin: append a receipt line and commit; the last reader archives it.
- read: assistant 2026-01-15
-->
