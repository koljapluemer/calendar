# Calendar data format

The selected data directory is a flat collection of JSON files. Every `*.json`
file directly inside it is treated as one calendar entry; subdirectories are
not scanned. Files that are unreadable, malformed, or not JSON objects are
ignored.

```json
{
  "date": "2026-08-29",
  "content": "the entry's text",
  "done": false
}
```

- `date`: calendar date in `YYYY-MM-DD` format.
- `content`: plain-text string, displayed verbatim.
- `done`: boolean indicating completion.

For compatibility, a missing or non-boolean `done` is read as `false`, a
missing or non-string `content` as an empty string, and an invalid `date` as the
current day. Scripts should write all three fields and should not rely on extra
fields being preserved when the app next saves an entry.

New files conventionally use `<date>-<6 random hex characters>.json`. The
filename is only a unique identifier: the JSON `date` field is authoritative,
and changing it does not require renaming the file. Use a temporary file and an
atomic rename when updating an entry so the app never observes partial JSON.
