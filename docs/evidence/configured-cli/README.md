# Configured CLI conversation evidence

Captured October 6, 2026 from the 0.5.1 change on macOS 27.2. This is a nonvisual execution-policy change; the conversation and Settings layouts are unchanged.

## Reproduce

After building this revision's core framework in `build/cli-configured-validation`:

```sh
bash scripts/test_configured_cli_conversations.sh \
  build/cli-configured-validation docs/evidence/configured-cli \
  > docs/evidence/configured-cli/fixture-output.txt
```

- [Actual fixture output](fixture-output.txt) records new and resumed Codex/Claude conversations, a denied write, restricted comparison summaries, and legacy-session retention.
- [Actual invocation records](requests.jsonl) contain the adapter's arguments, stdin, fixture output, session identifiers, and temporary working directories.

The harness calls the real `LocalPersonalAgent` core implementation with a deterministic Python executable and temporary fixture configuration. It performs no network/model request and reads no real account configuration or credentials. It proves configuration transport and execution-policy separation, not live provider interpretation, authentication, skill execution, or connector access.

## Validation and review

- Full unit suite: 144 passed, zero failures.
- After final completion/error handling changes: 38 PersonalAgentTests passed, zero failures.
- Parent independently reran the actual-adapter fixture captured here; all scenarios passed.
- The report shutdown/persistence harness passes after repairing two outdated test substitutes; product lifecycle behavior and existing assertions are unchanged.
- Parent reviewed new/resumed execution arguments, preservation of user permission settings without bypass flags, completion/error handling, transcript/draft/session migration, and continued restricted summaries. Scoped unsupported-version handling was corrected during review; no unresolved findings remain.
- Production icon matches the canonical green artwork. Website defaults and opt-in CLI selection are unchanged.

## Screenshots

No screenshot is claimed for this nonvisual change. The available computer-use tool blocks Terminal, so a relevant terminal capture could not be made. The actual command output and invocation records above provide the workflow evidence; an unchanged app screen would not demonstrate this fix.

## Video

No video is claimed for the same capture limitation. The reproducible fixture sequence and actual output above document each interaction and result. No live-provider demonstration or simulated UI recording is substituted.
