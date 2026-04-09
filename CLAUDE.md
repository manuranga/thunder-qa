Do acceptance testing for Thunder. Be critical. Discovering p1 api issues is the priority. Must perform Clean Up before stopping.

# Thunder

Thunder is a lightweight identity and access management product designed for managing different types of identities including customers, employees, businesses, and AI agents. It allows building secure and customizable authentication experiences across applications, services, and AI agents, and governing access control on those systems.

This is a docker compose debugging setup.

## Connections

Browser → net-dump:8091 (HTTPS) → Thunder:8090 (HTTPS)
Thunder → net-dump:9091 (HTTPS) → Consent:9090 (HTTP)
Thunder → PostgreSQL (thunderdb)
Consent → PostgreSQL (consentdb)

## Dump

All network traffic goes through a debugging proxy (net-dump) and written to `dump`. DB changes are also captured via CDC to `dump`.

- net: `{timestamp}_{from}-to-{to}_{METHOD}_{path}_{status}.txt`
- db: `{timestamp}_{dbname}_{OP}_{table}_{key}.txt`

## UI

- Console: Configuration portal - https://localhost:8091/console admin:admin
- Gate: Authentication portal - https://localhost:8090/gate

## How to Do Acceptance Testing

### Pick

- `findings/<Epic>/stories.md` : List of check boxes (- [ ] <Story>).Stories should cover all the variations or edge cases of an Epic. Completed ones are marked with a check mark. Each <Story> is a single line, in one of following formats
  - User Story: Reads as a continuation of `As a <Persona> I should be able to `.
  - NFR Story: Starts with "Thunder must "
- `findings/<Epic>/issue-<p>-<c>-<d>.md` : Issue report eg issue-p1-ux-password-in-plain-text.md. Priorities(<p>) are p1, p2, p3. Categories(<c>) are ui, ux, api, db, ect.

`cd user-stories && tail -n +1 */stories.md`

Pick a **single** Epic (cover breadth first yet prioritize by importance), then at most 3 (related/interdependent) stories in it.

### Test

- Create extensions if needed
- Perform black box testing. Assume the previous tester left the docker compose up. Prefer UI tests over backend tests. UI tests are performed using playwright-cli.
- **MUST** Read all relevant `dump/*.txt` files. Use an `Explore` task if needed. You may delete `dump/*` during the tests if needed. Keep an eye out for anything suspicious, not just what we are testing.
- Poke the black boxes directly to investigate or reveal non-ui issues.
- Report issues as you go. Don't wait till the end, create and modify often.
- Add any and all Epics and Stories you can imagine or came across that the product does/should support to stories.md files.
- Document every Epic and Story you can think of or have encountered; anything the product currently supports or should support.

You may imagine and do additional Stories in the same Epic that are related/prerequisite as you go (not a priority), but be sure to write and mark those as well. If you feel like you picked too many stories, feel free to drop them anytime after updating relevant files, next tester will pick them up.

### Extensions

For some tests you may need to extend the docker setup. Eg: add a mock service provider and wire it though net-dump. Modify docker files and create a reusable `extensions\<d>` dir. Must contain a `README.md` file. Be terse.

### playwright-cli - browser automation from terminal

Must use headed mode.

- browser: open --headed [url], attach [name], close, goto <url>, resize <w> <h>
- nav: go-back, go-forward, reload
- interact: click/dblclick/hover <target>, type/fill <target> <text>, drag <from> <to>, select <target> <val>, check/uncheck <target>, upload <file>
- keys: press/keydown/keyup <key>
- mouse: mousemove <x> <y>, mousedown/mouseup [btn], mousewheel <dx> <dy>
- inspect: snapshot [el], eval <func> [el], console [level], network
- dialog: dialog-accept [prompt], dialog-dismiss
- capture: screenshot [target], pdf, video-start/stop, video-chapter <title>, tracing-start/stop
- tabs: tab-list, tab-new [url], tab-close [idx], tab-select <idx>
- state: state-load/save <file>, delete-data
- cookies: cookie-list, cookie-get/set/delete <name>, cookie-clear
- storage: {local,session}storage-{list,get,set,delete,clear}
- network: route <pattern>, route-list, unroute [pattern], network-state-set <online|offline>
- debug: run-code [code], show, pause-at <loc>, resume, step-over
- sessions: list, close-all, kill-all
- setup: install, install-browser [browser]
- flags: --raw, --help [cmd], --version

### Report Format

The issue MUST NOT contain any solutions, only the steps and evidence. Don't assume solutions, because there could be multiple ways to solve, or even architectural level solutions that make the whole issue obsolete. Don’t even include the expected behavior. Keep in mind, other engineers do not have the same setup (dump, docker) as you, so report in a generic way. Even better, write from the perspective of an actual user, if possible. Assume the reader is an expert in the product. Format it such that it can be the body of a GitHub issue. Be terse.

## Clean Up

- Update the findings if you haven't already, refine as needed.
- Organize/split/merge/move/rephrase the Epics/Stories (use an Agent to fix, Sonnet, foreground)
- Merge/move issue-* (another Agent, after above finish).
- Move changes you did to docker files to `extensions\<d>` as `.diff` and reset the original git committed files.
- `docker compose down -v && rm -f dump/*` and close the tabs.
- `docker compose up -d` and verify. Leave the setup in a good state for the next tester.
