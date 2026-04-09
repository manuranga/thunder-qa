Do acceptance testing for Thunder. Be critical.

# Thunder

Thunder is a lightweight identity and access management product designed for managing different types of identities including customers, employees, businesses, and AI agents. It allows building secure and customizable authentication experiences across applications, services, and AI agents, and governing access control on those systems.

This is a docker compose debugging setup.

## Connections

Browser → net-dump:8091 (HTTPS) → Thunder:8090 (HTTPS)
Thunder → net-dump:9091 (HTTPS) → Consent:9090 (HTTP)
Thunder → PostgreSQL (thunderdb)
Consent → PostgreSQL (consentdb)

## Dump

All network traffic goes through a debugging proxy (net-dump) and written to `./dump/`. DB changes are also captured via CDC to `./dump/`.

- net: `{timestamp}_{from}-to-{to}_{METHOD}_{path}_{status}.txt`
- db: `{timestamp}_{dbname}_{OP}_{table}_{key}.txt`

## UI

- Console: Configuration portal - https://localhost:8091/console admin:admin
- Gate: Authentication portal - https://localhost:8090/gate

## How to Do Acceptance Testing

### Pick

- ./user-stories/<Epic>/stories.md : List of check boxes (- [ ] <Story>). Each <Story> is a single line that reads as a continuation of `As a <Persona> I should be able to <Story>`. Stories should cover all the variations or edge cases of an Epic. Completed ones are marked with a check mark.
- ./user-stories/<Epic>/issue-<p>-<c>-<d>.md : Issue report eg issue-p1-ux-password-in-plain-text.md. Priorities(<p>) are p1, p2, p3. Categories(<c>) are ui, ux, api, db.

`cd user-stories && tail -n +1 */stories.md`

Pick a **single** Epic (cover breadth first yet prioritize by importance), then at most 3 (related/interdependent) stories in it.

### Test

For the selected Stories:

- Perform black box testing. Assume the previous tester left the docker compose up. Prefer UI tests over backend tests. UI tests are performed using playwright-cli.
- Read all relevant `./dump/*.txt` files. Narrow down using CLI tools. Use an `Explore` task if needed. You may delete `./dump/*` during the tests if needed.
- Poke the black boxes directly to investigate or reveal non-ui issues.
- Report issues as you go. Don't wait till the end, create and modify often.
- Add any and all Epics and Stories you can imagine or came across that the product does/should support to stories.md files.
- Document every Epic and Story you can think of or have encountered; anything the product currently supports or should support.

You may imagine and do additional Stories in the same Epic that are related/prerequisite as you go (not a priority), but be sure to write and mark those as well. If you feel like you picked too many stories, feel free to drop them anytime after updating relevant files, next tester will pick them up.

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

The issue MUST NOT contain any solutions, only the steps and evidence. Don't assume solutions, because there could be multiple ways to solve, or even architectural level solutions that make the whole issue obsolete. Don’t even include the expected behavior. Keep in mind, other engineers do not have the same setup (dump, docker) as you, so report in a generic way. Even better, write from the perspective of an actual user, if possible. Assume the reader is an expert in the product. Format it such that it can be body of a GitHub issue. Be terse.

## Clean Up

- Double check relevant md files, refine as needed.
- Organize/split/merge/rearrange the Epics/Stories. Use an Agent.
- Improvements to the docker setup are welcome, as long as they are general and not specific to the test. Be sure to document it tersely in @additional-docker.md. Eg: add a mock service provider and wire it though net-dump.
- `docker compose down -v && rm -f ./dump/*` and close the tabs.
- `docker compose up -d` and verify (no need to check the ui). Leave the setup in a good state for the next tester.
