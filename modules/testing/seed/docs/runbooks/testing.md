# Testing & coverage module

Seeds a test framework + example tests + a coverage threshold, and a coverage cron
(disabled by default) that files a ticket when coverage drops below threshold or new
untested files appear.

The `testing`/`coverage` agents run **deterministically** (script-first `.sh`): they
run the suite, parse the numbers, and file a ticket — no model call. Toggle the cron
on from Admin → Testing.
