# Data model and privacy

## Local document schema

Saved poems are stored as individual records in the browser IndexedDB database `verse-local-poems`, object store `poems`. Older Verse collections are copied from `localStorage["verse_poems"]` into IndexedDB on initial use. This is non-destructive: the old storage key is retained and is not synchronized with new changes.

```json
{
  "id": "generated-uuid",
  "title": "Untitled Poem",
  "content": "The poem's exact text",
  "selected_poet": "dickinson",
  "is_public": false,
  "created_at": "2026-10-12T00:00:00.000Z",
  "updated_at": "2026-10-12T00:00:00.000Z"
}
```

`selected_poet` is optional. The `is_public` field is a legacy local schema field; **it does not publish writing** and does not implement access control. Publication only occurs through explicit third-party sharing. Unknown schema versions are rejected during backup import.

## Making and checking a backup

1. Open **My Collection** and choose **Export backup**.
2. Keep the downloaded `verse-backup-YYYY-MM-DD.json` file somewhere you can recover it, such as an encrypted drive or a trusted private backup location.
3. Before relying on it, open the file in a text editor and check that it is valid JSON with `schemaVersion: 1` and a `poems` array. Do not paste its contents into a public issue, gist, or other service: the file contains the full poem text in plain text.
4. To bring poems into another Verse installation, choose **Restore backup** and select that file. Keep the original file until you have confirmed that the poems you need are present.

The export is a portable copy of the collection, not an encrypted archive. Anyone who can read the file can read the writing inside it.

## Backup format

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-10-12T00:00:00.000Z",
  "poems": []
}
```

The exported file contains all writing in plain text: protect it accordingly. Import is capped at 20 MB; invalid JSON, malformed documents, and duplicate IDs are rejected. An import adds new IDs and keeps existing records in collisions. This is **merge-only**, not a restore-to-exact-state operation: it does not delete poems that are missing from the file or replace an existing poem when its ID is already present. Export a backup before importing, deleting, or clearing site data.

## Optional usability pilot

The separate `/study` route provides a voluntary research instrument. It collects only three sets of categorical answers in page memory and exports a JSON record with an allocation code, condition and prompt IDs, completion, usefulness, friction and reported adherence. It does **not** capture draft text, automatically transmit results, or write survey responses to browser storage. Reloading or leaving that page loses unsaved answers. Exported files may be re-identifiable if a researcher maintains an identified assignment log. The [pilot protocol](USABILITY_PILOT.md) describes these limits and the additional steps needed before conducting research with people.

## Trust and failure boundaries

- A public GitHub repository contains application source, **not users' poems**. Browser writing does not enter the GitHub repository.
- Typography is bundled with the site using Fontsource packages; the application does not request Google Fonts at runtime. Crimson Text and IBM Plex Mono are OFL-1.1 fonts. Normal network metadata is shared with the static site host when loading application assets.
- There is no built-in server account, remote database, or cloud backup. The only database is IndexedDB in the local browser profile.
- Browser-local storage is not encrypted by Verse or protected by per-person logins. People sharing the same device **and browser profile** have access to the same saved poems. Use separate browser profiles or device accounts if you need separation.
- A browser can deny IndexedDB or clipboard access, or storage can reach its quota. Save actions report failure without claiming success or deleting unsaved editor text.
- Each current save, edit, delete, and backup import executes in an IndexedDB readwrite transaction. Stale edits of the same poem are refused, retaining the draft with a separate-copy recovery option.
- First-use migration validates the legacy collection before writing anything and inserts records and a copy-once marker in one transaction. Malformed old data is not overwritten. Reload older Verse tabs before further writing; older localStorage-only clients are not coordinated with IndexedDB.
- Clearing site data, private browsing, or changing domain/origin can orphan prior poems. There is no migration from a previous Lovable domain unless its browser data is exported separately.
- Browser storage is readable by JavaScript executing in this origin. Treat external scripts, dependency updates, and XSS prevention as privacy-critical.
- Clicking Tumblr or X first asks for confirmation. If accepted, opening the share URL transmits prefilled poem text to the chosen service **before any final post is published**. Native sharing and copying require separate user actions; review destination privacy terms.
- Never commit local `.env`, backup JSON files with real writing, access tokens, or credentials.

## Data migration

The original private project's localStorage key was also `verse_poems`; moving to a new origin does **not** move browser data. Export via the original site if still available, and import into this site, or retrieve records directly through browser developer tools with appropriate care. Do not assume old data was automatically transferred.
