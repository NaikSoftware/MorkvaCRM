# Inbox research digest (2026-11-14)

"(snippet)" = from a search summary, page not fetched.

## 1. Strongest patterns

| Pattern | Who |
|---|---|
| **Overdue / Today / Upcoming buckets**; overdue folds into Today | [folk](https://help.folk.app/en/articles/15869200-tasks) (Overdue·Today·Upcoming·Done), [HubSpot](https://knowledge.hubspot.com/tasks/filter-tasks-and-manage-task-views) (Due today·Overdue·Upcoming views), [Todoist Today](https://www.todoist.com/help/articles/plan-your-day-with-the-today-view-UVUXaiSs) (Overdue section + Reschedule), [Things](https://culturedcode.com/things/support/articles/2803579/) |
| **Week strip + dot = has items + month picker** | [Todoist Upcoming](https://www.todoist.com/inspiration/todoist-upcoming-view) ("tap the date", swipe weeks, dot under busy days) |
| **Urgency colour + red badge** | [Attio](https://attio.com/help/reference/attio-101/productivity/introduction-to-tasks) red overdue / orange this week; folk red/orange dot on records; [Pipedrive](https://support.pipedrive.com/en/article/what-is-the-red-number-on-the-activities-icon) badge = overdue + today |
| **Relative reminder presets, one default** | [Trello](https://www.atlassian.com/blog/trello/custom-due-date-reminders): none, at due, 5/10/15 min, 1/2 h, 1/2 days, default 1 day; [HubSpot](https://knowledge.hubspot.com/tasks/task-reminders-and-daily-digest): at due, 30 min, 1 h, 1 day, 1 week, custom; [Todoist](https://todoist.com/help/articles/205348301) auto 30 min when a time is set |
| **Date-only items fire at a fixed morning time** | [Pipedrive all-day](https://support.pipedrive.com/en/article/activity-reminder-notifications-in-the-mobile-app) 09:00 day-of/1 d/2 d; folk 08:00 |
| **Few absolute date presets** | Attio Today·Tomorrow·Next week·Custom; folk tomorrow·next Monday·next month; [KeyCRM](https://help.keycrm.app/uk/tasks/iak-stvoriuvati-ta-pratsiuvati-z-zavdanniami) 5 presets |
| **Create from record → auto-linked, shown on record tab** | Attio `t`, folk, KeyCRM (nav button to order/client) |
| **Assignee defaults to creator; notify on assign** | Attio, folk, KeyCRM; [ClickUp](https://help.clickup.com/hc/en-us/articles/6325931822359-Delegate-reminders) "delegate" = change assignee (snippet) |
| **Postpone relative to now** | KeyCRM +1 h/1 d/1 w/1 m (from *now* if overdue); [Linear](https://linear.app/docs/inbox) `H` snooze/reminder → lands in Inbox |
| **Natural-language quick add** | [Todoist](https://todoist.com/help/articles/115001745265) (click a parsed word to un-parse); TickTick, Attio (snippet) |
| **Morning digest** | HubSpot weekday 8 am digest; Pipedrive morning summary |

## 2. Recommendations

1. **One list, day-scoped, with an always-visible "No date" shelf.** Today = Overdue (tasks only) → timed items by time → untimed "today" items → **No date** (undated notes/tasks; this *is* the sticky-note board). Other days: that day only. A pure day filter would hide sticky notes.
2. **Week strip**: 7 days, dot = items, red dot only on Today when overdue exists, "Today" chip, swipe/arrows for weeks, month label → month picker. No separate Upcoming screen.
3. **Row anatomy, max two lines**: leading checkbox (task) or tinted sticky surface with no checkbox (note) · title · meta: time · bell if reminder · linked-card chip (collection icon + card title, tap opens card) · assignee avatar **only when not me** / "from Anna" when assigned by someone else.
4. **One composer, type toggle**: task ⇄ note is a toggle in the composer. Notes are *dismissed* (archived), tasks are *checked*.
5. **Quick add defaults**: date = day selected in the strip (No date if added on the shelf), assignee = me, no reminder until a time exists. v1: chip buttons (date, time, bell, card, person); parse only date/time words, shown as a removable chip (Todoist un-parse).
6. **Reminder presets**: At time (default once a time is set), 15 min, 1 h, 1 day before, Custom. Date-only items: "Morning of" at a workspace morning time (09:00).
7. **Date presets**: Today, Tomorrow, Next Monday, Pick…; time presets Morning / Afternoon / Evening.
8. **Overdue**: only tasks go overdue; notes never nag. Overdue tasks sit in Today's Overdue group with "2 d late" in red, one-tap Postpone (+1 h, Tomorrow, Next week, computed from now like KeyCRM) and "Move all to today". No silent date moves.
9. **Assignment**: show a Mine · Assigned by me · All filter only when the workspace has members; assignee sees a "new" dot until opened.
10. **Card link both ways**: "Add to Inbox" from a card pre-links it; the card shows its open Inbox items.
11. **Badge** = my overdue + due-today tasks (Pipedrive), excluding notes.
12. **Honest delivery**: no server on Spark, so assignees learn of tasks only when their app is open and reminders fire only on devices with an open tab. On open, show "3 reminders while you were away" and mark them seen.

Skip in v1: priorities, labels, projects, recurrence.

## 3. Complaints / anti-patterns

- **Reminders silently not firing**: HubSpot users get no email, pop-up or bell for tasks ([thread](https://community.hubspot.com/t5/Sales-Hub-Tools/We-are-not-receiving-Task-Notifications-or-reminders/td-p/449783)). → Show permission/delivery state in the UI.
- **No overdue follow-up**: "[Reminder emails for overdue tasks](https://community.hubspot.com/t/reminder-emails-for-overdue-tasks/3929)" open from 2017 to 2025; users want repeated nudges or a past-due summary.
- **Short lead time**: Trello max 2 days, [TRELLO-802](https://jira.atlassian.com/browse/TRELLO-802) unresolved (snippet).
- **No bulk postpone**: Pipedrive users ask to push all activities forward by a day; bulk edit only sets one shared date (snippet, community link redirects).
- **Overdue too early**: Pipedrive multi-day tasks go overdue at start time ([thread](https://community.pipedrive.com/discussion/13338/how-to-show-multi-day-task-activities-as-overdue-only-when-final-day-has-passed), snippet).
- **No mobile alerts**: folk notifications not in the mobile app ([help](https://help.folk.app/en/articles/8174491-faq-reminders), snippet); ClickUp reminders lack phone alerts ([feedback](https://feedback.clickup.com/feature-requests/p/notifications-for-remindersdelegated-tasks), snippet).
- **Notion**: no recurring reminders ([2sync](https://2sync.com/blog/how-to-set-reminders-in-notion), snippet).
- **Reminder split from the note**: Google moved Keep reminders to Tasks, so editing needs another app and location reminders were lost ([Gadget Hacks](https://android.gadgethacks.com/news/google-keep-loses-key-reminder-features-in-tasks-migration/), [GTD forum](https://forum.gettingthingsdone.com/threads/google-just-wrecked-keep-reminders.19518/)). Keep the reminder on the item.

## 4. Web Notification API realities

- **Only while a tab is open.** Without a push server nothing fires when the browser or tab is closed. Notification Triggers (scheduled local notifications) finished its origin trial with launch "not started" ([Chrome](https://developer.chrome.com/docs/web-platform/notification-triggers)).
- **Background tabs are throttled.** Chrome M87+ limits timer wake-ups in tabs hidden for more than 5 min to once per minute ([Chromium](https://blog.chromium.org/2020/11/tab-throttling-and-more-performance.html)). Expect ~1 min lateness; check `fireAt <= now` on a tick and on `visibilitychange`.
- **Ask in context, from a click.** Firefox 72+ shows only a URL-bar icon without a user gesture; ~99% of prompts went unaccepted ([Mozilla](https://hacks.mozilla.org/2019/11/upcoming-notification-permission-changes-in-firefox-72/)). iOS allows it only for Home-Screen web apps, after a tap ([OneSignal](https://documentation.onesignal.com/docs/web-push-for-ios)). web.dev: prompting on landing is "the worst thing"; use **double permission** (own explainer → browser prompt) ([web.dev](https://web.dev/articles/push-notifications-permissions-ux)). HubSpot does the same ([KB](https://knowledge.hubspot.com/acccount-management/set-up-browser-notifications)). → Ask the first time a user sets a reminder.
- **Chrome quiet UI**: auto-enabled for users who usually block and for sites with very low opt-in rates; the prompt collapses to an omnibox icon ([Chromium](https://blog.chromium.org/2020/01/introducing-quieter-permission-ui-for.html)).
- **Denied is permanent for the site**: it can't re-ask. Show a "Blocked: enable in site settings" row; in-app badge and overdue still work.
- **Chrome Android**: `new Notification()` throws "Illegal constructor"; use `ServiceWorkerRegistration.showNotification()` ([Chrome](https://developer.chrome.com/blog/notifying-you-of-changes-to-notifications)). `web/` has no custom SW; check what the Flutter build registers.
- **Click**: the default action focuses the notification's tab ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Notification/click_event)); in `onclick`, navigate to the item and `close()`. For SW notifications, `notificationclick` → `clients.matchAll` → `focus()`, else `openWindow()` ([web.dev](https://web.dev/articles/push-notifications-common-notification-patterns)).
- **Multiple tabs each fire**: set `tag` = item id so a later one replaces the earlier ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Notification/tag)); or elect one tab (my suggestion).

**Gaps:** Pipedrive desktop presets, TickTick defaults, Twenty tasks (docs 404) unverified.

## 5. xTiles (owner's reference)

Notes-first canvas app with a task layer, documented in its [help center](https://help.xtiles.app/llms.txt).

- **Two "inboxes".** The notes [Inbox](https://help.xtiles.app/en/articles/12638802-what-is-inbox.md) is a staging panel for tiles (notes, photos, audio, clips) that you later drag onto a page. In the [Task List](https://help.xtiles.app/en/articles/8372890-task-list.md), "Inbox" means **tasks with no due date**. Sections: Today (overdue included) · Upcoming · Inbox · Assigned · Priority · Completed. → **Copy** "undated = Inbox, always visible" (it matches rec 1). **Avoid** one word meaning two places.
- **Date chip colour** ([Scheduling](https://help.xtiles.app/en/articles/14999739-scheduling-a-task.md)): green = today, yellow = tomorrow, red = overdue. Overdue sits at the top of Today with **"Reschedule All"**. → Copy.
- **Reminder presets are day-based only**: "At the same day", 1, 2 or 3 days before, 1 week before. There is no "15 min" or "1 h", which is too coarse for a call at 14:00. → Avoid; keep minute and hour presets.
- **Indicator on the checkbox** when a task repeats or has a reminder ([May 2026](https://xtiles.app/en/updates/may-2026/)). → Copy: no extra bell column.
- **Day navigation** ([My Planner](https://help.xtiles.app/en/articles/11028546-how-to-use-my-planner.md)): a Daily/Weekly/Monthly period selector with ‹ › arrows, and a dot that greys out on the current period and turns blue when you leave it. Daily view = tiles: that day's Tasks, a Schedule timeline (tasks + Google/Outlook events), Captured and Recent. Tasks created in a day tile get that date. → Copy the "back to today" dot and add-in-day-sets-date. Avoid the tile canvas, which is too heavy for a list inbox.
- **Assignment** ([Assigning](https://help.xtiles.app/en/articles/8372835-assigning-tasks.md)): only project members; personal projects auto-assign to me, shared ones start unassigned; the assignee **accepts or declines** in the notification centre. → Copy accept/decline only if task delivery matters. It adds a state.
- **Notes vs tasks**: any block can be turned into a task ("Turn into → Task"). The task is a line inside a note, not a separate item type. → Our toggle is simpler.
- **Notifications** ([Notifications](https://help.xtiles.app/en/articles/8373201-notifications.md)): a bell centre with All · Tasks · Events · Access · Collaboration tabs, plus a mobile morning summary. Browser alerts are opt-in under Profile → Notification ([enable](https://help.xtiles.app/en/articles/12638384-how-to-enable-notifications-in-xtiles.md)). They have servers and push; we don't.
