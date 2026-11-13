# Prior art: team collaboration and sharing views by link or email

**How to read the tags**
- **[P]**: from a fetched primary help page. The labels are a paraphrase of the page by the fetch tool, so treat exact wording as second-hand.
- **[S]**: from a search-result summary.
- **[C]**: from community forums or vendor blogs.
- **[I]**: my own inference.
- **[V-repo]**: I checked it in `the repo`.

The monday.com support page and the ClickUp public-sharing page both returned 403, so neither is verified from a primary page.

## 1. Product digest

### Airtable
**Roles**
- Workspace and base permissions are tracked separately. Your effective access is the higher of the two. Nobody can grant a role above their own. [P] https://support.airtable.com/docs/airtable-permissions-overview
- The level set is Owner, Creator, Editor, Commenter and Read only. Only Creator or Owner can change the schema. [P]
- **Billing:**
  - On Business, Editor and above are billable; Commenter and Read-only are not.
  - On Free, Read-only seats are unlimited, Editor-and-above seats are capped at 5, and Commenter seats at 50. [S] https://support.airtable.com/docs/how-collaborators-impact-billing.md
  - Sources conflict on how interface collaborators are billed on the Team plan. [S]

**View share menu** [P] https://support.airtable.com/docs/using-the-view-share-menu-in-airtable
- The entry point is "Share and sync", which offers "Create link to view" and then "Copy link". The menu also offers "Sync data to another base", "Publish to data library" and "Create a form view".
- "Link settings" contains these options:
  - "Allow viewers to copy data out of this view": controls batch copy and CSV download, not copying single cells. A search summary says it is ON by default [S].
  - "Show all fields in expanded records"
  - "Restrict access with a password" (paid plans)
  - "Restrict access to an email domain" (paid plans; one domain only; no list of individual emails [S]; viewers need an Airtable account with a verified email in that domain)
  - "Restrict access to enterprise email domains"
  - "Generate new link": the old URL dies
  - "Disable link": re-enabling brings back the same URL
- Base collaborators can always download CSV.
- Filters a viewer applies are ignored by CSV export, which returns the whole shared view.
- The view-share article does not mention Embed.

**Hidden fields** [P] https://support.airtable.com/docs/hidden-fields-in-view-share-links
- Hidden fields stay hidden, even in an expanded record.
- These fields always show anyway: the group-by field in a grouped grid, the calendar date field(s), the cover attachment in gallery or kanban, and the kanban stack field.
- Viewers must refresh to see visibility changes.

**Linked records** [C]
- In a share link, only the linked record's primary field is shown, and it cannot be expanded.
- "Show all fields" does not reveal other tables.
- Workaround people use: a rollup or text field on the parent record.
- Threads: https://community.airtable.com/other-questions-13/shared-view-with-fields-that-link-to-other-tables-20764 and https://community.airtable.com/other-questions-13/expanding-linked-records-in-shared-views-16360

**Invite links**
- Path: Share, then "Invite via link". The link carries a permission level plus "Only allow emails from" a single domain. [S] https://support.airtable.com/docs/creating-airtable-base-share-links
- A removed collaborator rejoined through an old invite link. [C] https://community.airtable.com/t/is-it-possible-for-ex-collaborators-to-join-using-the-old-link/48682

**Interfaces** [P] https://support.airtable.com/docs/managing-and-sharing-interfaces
- "Share interface" is separate from the base-level "Share" button.
- Sharing options:
  - Invite by email.
  - "+ Create new link", then "Create invite link".
  - "Share to web": read-only, one page, no account needed, Team plan and up. Its "Manage link settings" offers password, disable and regenerate, plus "Embed this page". You must also click "Enable public sharing".
- Permission levels are Editor, Commenter and Read only. There is no interface-level Creator, and interface-only collaborators cannot open the base.
- Invite links do not support passwords; only public pages do.
- **Access requests:** a user without access sees "Request access". The owner reviews it under "Manage access", then "Requests", with "Approve" and "Reject". A user can send one request every 12 hours.
- **Restrict interface sharing:** a per-interface toggle that turns invite links off.
- Outside guests require the Portals add-on (Business tier).

**Audit**
- An Enterprise Scale admin report lists every share link in the org ("View all" or CSV).
- The audit log keeps share events for 180 days.
- Admins can restrict share links org-wide.
- [S] https://support.airtable.com/docs/reports-airtable-enterprise-admin-panel.md

### Notion [P] https://www.notion.com/help/sharing-and-permissions
**Share menu**
- Contains the invite field, the people list, "Copy link" and a "Publish" tab.
- You can invite members or groups, or enter an email to add a guest. Pick a level, then "Invite".

**Levels**
- "Full access": can edit and reshare.
- "Can edit": cannot reshare.
- "Can edit content": databases only. Can edit entries and values, but not structure, views, sorts or filters.
- "Can create": Business plan and up. Can add entries without seeing other people's entries.
- "Can comment"
- "Can view"

**General access**
- "Only people invited"
- "Everyone at {workspace}", with a "Hide in search" option
- "Anyone on the web with link", with "Link expires"
- Enterprise can turn public links off.

**Other behaviour**
- Subpages inherit access, and the broadest grant wins.
- Guests need a Notion account. Anyone with an org-domain email is added as a member, not a guest.
- **Publish options** [S] https://www.notion.com/help/guides/publish-notion-pages-to-the-web
  - "Link expiring" / "Link expiration"
  - "Allow editing" (signed-in users)
  - "Allow comments"
  - "Allow duplicate as template"
  - "Search engine indexing" (on Sites, labelled "Discoverable on the web")
  - Publishing a page publishes its subpages too.
- **Guests are free.** Guest caps are reported as 10 on Free, 100 on Plus and 250 on Business [C].
- **Billing trap:** an invite can prompt you to upgrade a guest to a paid member. The fix is to choose "Skip for now". [S] https://www.notion.com/help/members-and-billing

### Google Drive, Docs and Sheets [P] https://support.google.com/drive/answer/2494822
- **Inviting:** "Share", enter an email or group, pick Viewer, Commenter or Editor. A "Notify people" checkbox controls the email, then "Send".
- **General access:** "Restricted", "Anyone with the link" (no sign-in needed) or "Your organization". The article only shows Viewer for the link, but that is not proof the link is limited to view.
- **Per-person menu:** "Remove access", "Add expiration" (work or school accounts, within one year) and "Transfer ownership".
- **Gear menu:**
  - Choose whether Editors, Commenters and Viewers may download, copy and print.
  - "Allow editors to change permissions and share".
- **Visitor sharing:** people without a Google account get a PIN by email. Verification lasts 7 days, and visitors can view, comment or edit. [S] https://www.boisestate.edu/oit/google-drive-at-boise-state-university/visitor-sharing-in-google-drive/
- **2021 retrofit:** Google added a `resourcekey=` to old "anyone with the link" files, which broke many links in the wild. [S] https://support.google.com/a/answer/10685032

### Trello [P] https://support.atlassian.com/trello/docs/adding-people-to-a-board/
**Inviting**
- "Share", search by name, username or email, choose member or observer, then "Share".
- An email address with no account gets an email to create one. Until they verify, they are a "virtual" member. Trello sends only one invitation.
- **Roles:** Admin, Member (sees and edits all cards) and Observer.
- **Guests:** anyone outside the Workspace who is added to a board becomes a guest. Free Workspaces allow 10 collaborators in total.
- **Join requests:** "Share", then "Join requests", then "Add to board" or "Delete".

**Invite link** [S] https://support.atlassian.com/trello/docs/inviting-people-by-using-a-shareable-link
- "Invite with link", which can grant member or observer. Observer requires Premium.
- To turn it off: "Delete link", then "Delete share link".
- Users disabled the wrong link, and Workspace-level links are disabled from a different page. [C] https://community.atlassian.com/t5/Trello-questions/How-to-disable-invite-link/qaq-p/577755

### ClickUp (not primary-verified, 403)
- **Guest levels:** "View only", "Comment", "Edit" (cannot delete) and "Full edit". View-only guests are free and unlimited on paid plans. Giving a guest any higher level makes them a "permission-controlled" guest. [S] https://help.clickup.com/hc/articles/6310022323991-Guests-overview
- **Public link:** turned on with "Share link with anyone" from the view's sharing panel. It needs no account and is read-only. Guests cannot create public shares. Advanced public settings are Enterprise only. [S, partly C]
- **Possible reclassification:** reports say ClickUp turned internal guests into "limited members" billed at the full member rate in late 2024. Unverified. [C] https://www.fast.io/resources/clickup-client-portal.md

### monday.com (not primary-verified, 403)
- A board view can be shared by public link or embed code, and turned off under "Share settings". Mirrored items do not appear.
- No native password or domain limit was found. Users ask for passwords on the forum, and a third-party Appfire add-on sells them. [S/C] https://community.monday.com/t/share-view-with-password-protection/29396

### Baserow [P] https://baserow.io/user-docs/public-sharing
**Link controls**
- "Share view", then "Create a private link", then "Copy link".
- "Restrict access with a password": at least 8 characters, stored encrypted.
- "Generate new URL": the old one dies at once.
- "Disable shared link".

**Exports and editing**
- "Allow export on shared view" is OFF by default and exports only visible fields under the active filters.
- The view is read-only; forms can only submit new rows.

**What visitors get**
- Hidden fields stay hidden in expanded rows.
- Visitors can add temporary filters.
- Changes the owner makes appear live.
- The view can be embedded with an iframe.

**Roles** [C/S]
- Roles are Admin, Builder, Editor, Commenter and Viewer, set per workspace, database, table or view.
- Free and Premium plans get only two workspace roles.

### NocoDB [P] https://nocodb.com/docs/product-docs/collaboration/share-view
**Link controls**
- "Share", then the "Share to web" tab, then the "Public link to <view>" switch, then "Copy URL".
- "Custom URL"
- "Restrict access with password": the password is never shown again.
- "Allow download" (CSV and XLSX): OFF by default.
- "Allow sync"
- "Set a language"

**Behaviour**
- Viewers are read-only. They can filter and sort, but nothing is saved.
- Filters and sorts on hidden fields still apply.
- If the view groups by a hidden field, the shared link shows it ungrouped.
- Every shared view has a "Report abuse" link.

**Roles**
- Owner, Creator, Editor, Commenter, Viewer and No Access, set per workspace and per base. [S]

**Security advisories** [S] https://osv.dev/vulnerability/CVE-2026-47379
- CVE-2026-28360: shared-view passwords were stored in plaintext before 0.301.3.
- CVE-2026-47379: a later timing-leak fix.

## 2. Patterns that come up again and again
1. **Two layers.** A workspace member list sits under per-object sharing. Effective access is the higher of the two. Nobody can grant above their own role. (Airtable, Notion, Baserow, NocoDB)
2. **"Edit content" is its own role, apart from "Edit structure".** Notion's "Can edit content" and Airtable's Creator-versus-Editor split both draw that line.
3. **A view link is read-only, anonymous and has its own settings:**
   - Common settings: password, one email domain, expiry, copy and download toggle, regenerate, disable.
   - Download defaults differ. Airtable reportedly turns it ON; Baserow and NocoDB turn it OFF.
4. **Hidden fields need explicit exceptions.** Airtable, for example, always shows the group-by, stack and cover fields. A linked record collapses to its title.
5. **Invite links carry a role** and sometimes a domain lock. Taking one down is a separate action ("Delete link" or "Reset"). Stale links are a recurring complaint.
6. **Inviting someone with no account sends them through the vendor's sign-up.** Trello treats them as "virtual", Google uses a visitor PIN, and Notion requires an account.
7. **Access requests** ("Request access", then Approve or Reject, rate-limited) stand in for a pending-invites list.

## 3. Pitfalls users complain about
- **Data leaking through relations:** links expose the primary field of linked records [C]. Grouping or stacking reveals hidden fields [P]. The "Show all fields in expanded records" toggle exposes the whole table [P]. CSV download returns the entire view whatever the viewer filtered [P].
- **Link sprawl:**
  - Only Airtable Enterprise gets an org-wide share-link report [S].
  - Removed people rejoin through old invite links [C].
  - Trello users disabled the wrong link [C].
  - Google had to retrofit 2021 links with a resource key [S].
- **"Anyone with the link" exposure:**
  - A Drive link set to anyone-with-link exposed data on 935k people. [S] https://www.malwarebytes.com/blog/news/2026/08/be-careful-what-you-put-in-anyone-with-the-link-google-docs
  - Shared Claude chats were indexed by search engines because the pages lacked `noindex`. [S] https://www.techrepublic.com/article/news-claude-shared-chats-google-search/
  - I found no Airtable-specific indexing evidence, so this is an analogy only.
- **Read-only is not copy-proof:** any read-only collaborator can duplicate the data. [C] https://community.airtable.com/legacy-product-ideas-75/major-security-hole-in-airtable-any-collaborator-even-read-only-collaborators-can-steal-100-of-your-data-with-one-click-41807
- **Guest and seat billing:** Notion upgrades a guest to a paid member unless you pick "Skip for now". ClickUp reportedly reclassified guests [C]. Free tiers have low guest caps (Trello 10, Notion reported 10) [P/C].
- **Domain restriction is too coarse:** it allows one domain only, with no list of individual emails (Airtable) [S].

## 4. MorkvaCRM facts that constrain the design [V-repo]
- **Workspace:**
  - Today `isWorkspaceOwner` is simply `request.auth.uid == workspaceId` (`firestore.rules:14-16`).
  - The rules header says to swap in a `memberships/{uid}` check with unchanged paths (`firestore.rules:3-10`).
- **Per-member data already exists:**
  - `members/{uid}/{sub}/...` holds Ask Morkva threads (`:115-119`).
  - `members/{uid}/grants/{moduleId}` holds module consent (`:122-131`).
  - A roster document at `members/{uid}` (not `memberships/`) would avoid two parallel trees [I].
- **Data layout:**
  - Views live inside the collection document as `views: [...]` (`lib/core/domain/collection.dart:51,128`).
  - Cards are flat `objects/{id}` documents holding `collectionId, rev, values` (`firestore.rules:47-55`).
  - View modes are table, board, list, calendar and summary (`lib/core/domain/view/view_definition.dart:9-10`; `docs/sdk/api.md:1133`).
  - Field types include `reference_field` and `calculated_field` (`lib/core/domain/types/`).

**What follows from that** [I]
- A Firestore read returns the whole document. Anyone who can read the live collection document therefore sees every view, the schema and all hidden fields. Anyone who can read the live `objects` sees every field value.
- So "hidden fields" and "locked filters" are cosmetic on live data. They are real only on a **published copy** that the owner's client writes.
- Row scoping per collection is enforceable: the rules can check `resource.data.collectionId` against what the user has been granted, and queries must filter on it.
- **No Cloud Functions (Spark plan) means:**
  - The server cannot send email. The Trigger Email extension needs Blaze.
  - Passwords cannot be checked or rate-limited on the server.
  - Nothing refreshes a published copy server-side.
- What the rules can enforce, using fields on the share document and `request.auth.token.email`:
  - expiry (`resource.data.expiresAt > request.time`)
  - disabling (delete or flag the share document)
  - an email allow-list (`request.auth.token.email in resource.data.emails && request.auth.token.email_verified`)
  - role checks
- **Download blocking is not enforceable.** Whatever is rendered can be copied, so the setting is only "Show Download CSV".
- **Spark daily quota:** about 50k reads and 20k writes per day (known Firebase limits, not fetched this session). A popular anonymous link reads from the owner's quota, so rows should be packed into a few chunk documents per view. Each document is capped at 1 MiB.
- **Sign-in:** auth is Google-only. A person without a Google account can still create one for an existing non-Gmail address (known Google feature, not fetched).
- **Email matching:** invites must match `token.email`. Gmail dot and alias variants and Workspace aliases cause mismatches, so the app needs a screen for that case: "This invite is for a@x.com. You're signed in as b@y.com — Switch account".

## 5. What fits a universal small-business CRM
- **Take:**
  - A workspace team with 4 roles: Owner, Admin, Editor, Viewer. Editor is Notion's "edit content" split: cards only, no schema, views, automations or modules.
  - Leave out Commenter until the card comments feed exists.
  - Invite by email plus one resettable invite link carrying a role, expiry and optional domain.
  - A pending-invites list.
  - A view link built Airtable/Baserow-style: read-only, hidden fields stay hidden, references show only the card title, Download OFF by default, Regenerate and Disable buttons.
  - Allow-listing by email on top of the link. This fixes Airtable's one-domain-only gap.
  - A single "Shared links" page listing every link in the workspace. This is the anti-sprawl fix that only Airtable Enterprise has.
  - Default to `noindex`.
- **Skip for now:**
  - Per-field ACLs on live data (not enforceable).
  - Passwords as "security": weak at best without a server, unless designed as part of the capability.
  - Live public editing.
  - Embeds, until hosting headers (`frame-ancestors`) are decided.
  - Seat billing.
- **Email delivery without a server:** "Copy invite link", the OS share sheet (`share_plus`) and a prefilled `mailto:`. The UI says "We don't send emails — share the link yourself." [I]

## 6. Three variants
The variants differ in three ways: what access attaches to, whether viewers see live data or a published copy, and whether viewers must sign in.

### Variant A — "Team workspace" (Trello/Airtable workspace style)
Access attaches to the **workspace**. Viewers see **live** data. Everyone **signs in with Google**.

**Where it lives**
- Settings, then "Team".
- There is no per-view sharing. "Copy link to view" on a view tab gives a deep link that only members can open.

**Roles**

| | Owner | Admin | Editor | Viewer |
|---|---|---|---|---|
| Read all collections and cards | ✓ | ✓ | ✓ | ✓ |
| Create, edit and delete cards | ✓ | ✓ | ✓ | – |
| Edit fields, views and collections | ✓ | ✓ | – | – |
| Automations and modules | ✓ | ✓ | run only [I] | – |
| Invite people and manage links | ✓ | ✓ (up to Admin) | – | – |
| Delete workspace or transfer ownership | ✓ | – | – | – |

**"Invite to {Workspace}" dialog**
- An "Emails" chip input, a role dropdown (default Viewer), then "Add".
- **"Invite link" section:** "Anyone with this link can join as [Viewer▾]". Options: "Expires [7 days▾]" and "Only emails from [@acme.com]" (optional, multiple allowed). Buttons: "Copy link", "Reset link" and "Turn off".
- Footer: "Share via…" (share sheet) and "Done".

**Team page tabs**
- "Members (n)": avatar, name, email, role dropdown, "Last active", "⋯ Remove".
- "Pending (n)": email, role, "Invited by", "Expires in 5 days", "Copy link", "Revoke".
- "Access requests": "Approve as [Viewer▾]" or "Decline".

**Someone without an account**
1. They open the link and land on "{Owner} invited you to {Workspace}".
2. "Continue with Google".
3. If the email does not match: "Switch account".
4. Their membership document is created and the rules validate it against the invite document.

**Trade-offs**
- Simplest; matches the path already planned in the rules header.
- It cannot share with a client safely, because all members see everything.
- Viewer still sees every field.
- Feasible on Spark without Functions: **yes**.

### Variant B — "Publish a view" (Airtable view link / Baserow / NocoDB)
Access attaches to a **single view**. Viewers see a **published copy**. Viewers are **anonymous, or signed in only if you restrict by email**.

**Where it lives**
- View tab "⋯", then "Share view…".

**"Share '{View}'" dialog**
1. A "Publish this view" switch, with a summary line: "6 of 11 fields · 42 cards · filters locked".
2. **"Who can open"** radio:
   - "Anyone with the link" (no sign-in)
   - "Only people I add" (an email chip input; they sign in with Google; this is the "share by email" path)
3. **"Link settings"**:
   - "Expires [Never ▾ / 1 day / 7 days / 30 days / Pick date]"
   - "Show 'Download CSV'", OFF, with the helper text "Viewers can still copy what they see"
   - "Linked cards show: title only" (fixed and explained)
   - "Calculated fields: published values"
4. Status: "Updated 3 min ago · Update now", and "Auto-update while Morkva is open on this device".
5. Footer: "Copy link", "Regenerate link" and "Unpublish".

**How it works** [I]
- The owner's client writes `publicViews/{128-bit token}` as a top-level document holding only visible fields, the rows that pass the filters, reference titles and resolved calculated values.
- Rows are packed into chunk documents.
- Rules: `get` only, no `list`, plus the expiry and email checks above.
- The viewer page is a no-sign-in web route with a `noindex` header and a "Report abuse" link.
- **If a password is offered:** the document id is derived as hash(token + password) on the client. The password then acts as part of the link, not as a server check. Require at least 8 characters and say so honestly, or leave passwords out of v1.

**Who has access**
- Settings, "Shared links", lists every published view: view, audience, created by, expires, "Last published", and "Unpublish".
- Anonymous opens cannot be counted without allowing public writes.

**Trade-offs**
- Hidden fields and filters are genuinely enforced, and reference leaks are designed out.
- Fits "send the client their orders list".
- The copy goes stale when no editor is online, because nothing refreshes it server-side.
- Read-only.
- Chunk writes use the write quota; viral links use the read quota.
- Feasible on Spark: **yes, partly**. Freshness and the password are weak.

### Variant C — "Guests on a collection" (Notion guests / Airtable interface-only / ClickUp guests)
Access attaches to a **collection**. Viewers see **live** data. Guests **sign in with Google**. It sits on top of Variant A's team.

**Where it lives**
- A "Share" button in the collection header.

**"Share '{Collection}'" dialog**
- **"People with access"**:
  - "Everyone in {Workspace} · per their team role" (inherited, not editable here)
  - Each guest row: "Can view ▾ / Can edit cards ▾ / Remove".
- **"Add guests"**: an email chip input with a role dropdown, then "Invite". Helper text: "Guests see only this collection — all its cards and fields."
- A warning banner when a reference field points elsewhere: "Linked cards from 'Companies' will show as 'Restricted card'."

**Team page**
- A "Guests (n)" tab listing each guest's collections, with "Remove from all".

**Rules** [I]
- Grants are stored per guest, for example `members/{uid}.collections`.
- `objects` reads must filter on `collectionId` within those grants.
- Collection documents are readable when granted. Every view and the schema leak to the guest, so there is no field hiding.

**Trade-offs**
- Real live collaboration with clients and contractors, scoped per collection.
- Rule complexity, query discipline and reference rendering all get harder.
- Field-level or view-level scoping would need the published copy from Variant B anyway.
- Feasible on Spark: **yes, partly** (per collection only).

### Recommendation [I]
- Ship **A** first. It is the foundation and maps onto the planned rules swap.
- Then ship **B**: "Share view" with "Anyone with the link" or "Only people I add". It covers "share views by link or email" with real field hiding.
- Defer **C** until there is demand. Rebuild it on per-view published copies if people need field-level guest access.
- Add Commenter only once the comments feed exists.

---
- **Skipped:** the ClickUp and monday.com primary pages (403), Airtable's linked-record behaviour (forum posts only), and Firebase Spark quotas and Google "use existing email" (from memory, not fetched).
- **Risk:** under Variant B, any "password", "no download" or "hidden" claim is only as strong as the published copy and the token, because no server checks it.