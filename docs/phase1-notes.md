# Phase 1 notes: Log Ingestion

## Goal
Load pre-recorded attack logs and my laptop's live Windows logs into Splunk, parsed correctly and ready for hunting.

## What was built
- **Splunk app `catch_the_breach`** (`splunk-app/catch_the_breach`), deployed to `D:\Splunk\etc\apps\`:
  - `indexes.conf`: `attack` (10-year retention, 5 GB cap) and `endpoint` (30-day retention, 3 GB cap)
  - `inputs.conf`: Sysmon, Security, System and PowerShell event logs into `endpoint`, as XML (`renderXml = true`), new events only
  - `props.conf`: `MAX_DAYS_AGO = 3650` for `XmlWinEventLog`, so timestamps from 2020 are accepted
  - `metadata/default.meta`: settings exported to all apps
- **`scripts/get-datasets.ps1`**: downloads Atomic Red Team Sysmon logs from Splunk's `attack_data` repository by direct path and checks each file is Sysmon XML
- **`scripts/ingest.ps1`**: loads each dataset into `index=attack` with `sourcetype=XmlWinEventLog`, `source=XmlWinEventLog:Microsoft-Windows-Sysmon/Operational`, and the technique ID as `host`

## Attack data loaded (Test 3)
9 techniques, 72,113 events.

| Technique (host) | Events | First seen | Last seen |
| --- | --- | --- | --- |
| T1003.001 | 7,960 | 11/03/2020 21:20 | 02/04/2021 03:05 |
| T1003.002 | 7,016 | 10/08/2020 16:31 | 01/15/2025 16:16 |
| T1053.005 | 6,277 | 12/07/2020 18:03 | 12/07/2020 18:09 |
| T1059.001 | 21,926 | 03/02/2021 04:22 | 03/06/2021 01:33 |
| T1070.001 | 6,226 | 10/09/2020 14:38 | 10/09/2020 14:47 |
| T1105 | 2,290 | 03/25/2021 03:19 | 12/08/2024 05:39 |
| T1136.001 | 6,386 | 10/09/2020 16:09 | 10/09/2020 16:17 |
| T1547.001 | 6,287 | 11/27/2020 14:15 | 11/27/2020 14:20 |
| T1562.001 | 7,745 | 11/06/2020 17:31 | 03/02/2021 23:04 |

T1003.002 and T1105 extend into 2024–2025 because those files contain later re-runs appended to the original recordings.

## Data quality (Test 9)
- Before the fix: 32 `DateParserVerbose` warnings. 20 were "outside of the acceptable time window" for T1003.001 (recorded November 2020, older than Splunk's 2,000-day default `MAX_DAYS_AGO`).
- After the fix: 7 warnings in the last 15 minutes, all "Failed to parse timestamp in first MAX_TIMESTAMP_LOOKAHEAD (128) characters". Splunk gives those few events the previous event's time, seconds apart within the same run. Accepted as a known issue; no effect on hunting.

## Problems and fixes
| Problem | Cause | Fix |
| --- | --- | --- |
| Find More Apps returned 404 | In-app Splunkbase browsing unavailable on this install | Downloaded add-ons from Splunkbase and installed with `splunk install app <file> -update 1` |
| Browser blocked `.spl` downloads | `.spl` is an unfamiliar archive type to the browser | Kept the files manually (Splunkbase is the trusted source) |
| `splunk restart`: "Access is denied" | PowerShell not running as administrator | Always run Splunk commands from an admin PowerShell |
| `get-datasets.ps1` (GitHub API version) found no files | API listing failed in Windows PowerShell | Rewrote it to download directly from the standard `atomic_red_team/windows-sysmon.log` path |
| `index=attack` empty after running the clean command | `clean eventdata` wipes the whole index | Re-ran `ingest.ps1` once; the clean step is only for duplicate loads |
| Old events stamped with wrong time | Events older than 2,000 days rejected by default | Added `props.conf` with `MAX_DAYS_AGO = 3650`, cleaned `index=attack`, re-ingested |
| SPL typed into PowerShell | SPL runs only in Splunk's search bar | Run all tests in Search & Reporting |

## Test results
| Test | What it proves | Result |
| --- | --- | --- |
| 1 | Splunk loaded the app's indexes and inputs (`btool`) | |
| 2 | Dataset files are real Sysmon XML | Pass: 9 files downloaded and validated by `get-datasets.ps1` |
| 3 | Every dataset arrived with correct dates | Pass: 9 techniques, 72,113 events, 2020–2025 |
| 4 | Sysmon EventCodes extracted | |
| 5 | Process command lines readable | |
| 6 | LSASS access visible | |
| 7 | Four sources flowing into `index=endpoint` | |
| 8 | My own commands found in `index=endpoint` | |
| 9 | No significant parsing errors | Pass: 7 accepted fallback-timestamp warnings |
| 10 | Licence use well under 500 MB a day | |

## What I learned
- `sourcetype` and `source` decide whether the add-ons extract fields; wrong values mean raw text and broken searches.
- Splunk uses each event's own timestamp, so old datasets need the time picker on All time and a raised `MAX_DAYS_AGO`.
- Index retention (`frozenTimePeriodInSecs`) must cover the data's age, or Splunk deletes it on arrival.
- `clean eventdata` is destructive: it empties a whole index.
- Keeping Splunk configuration as an app in Git makes it reviewable and repeatable.
