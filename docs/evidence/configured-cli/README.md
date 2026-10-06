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

- Full unit suite after integrating current main: 145 passed, zero failures.
- After final completion/error handling changes: 38 PersonalAgentTests passed, zero failures.
- Parent independently reran the actual-adapter fixture captured here; all scenarios passed.
- The report shutdown/persistence harness passes after repairing two outdated test substitutes; product lifecycle behavior and existing assertions are unchanged.
- Parent reviewed new/resumed execution arguments, preservation of user permission settings without bypass flags, completion/error handling, transcript/draft/session migration, and continued restricted summaries. Scoped unsupported-version handling was corrected during review; no unresolved findings remain.
- Production icon matches the canonical green artwork. Website defaults and opt-in CLI selection are unchanged.

## Screenshots

The PNG captures show a read-only browser replay of the actual invocation records above: configured new and resumed requests, a denied action, a restricted report, and legacy-history reconstruction. They show the nonvisual adapter workflow, not the production app UI or a live provider. The replay uses the records captured from the reviewed code; its controls do not run commands.

## Video

[Recorded-call walkthrough](configured-cli-records.mp4) sequences the captured new-session, follow-up, denied-action, and legacy-history views. Timing is edited to five-second holds. This is a deterministic fixture replay, not continuous recording of execution or proof that a live skill/connector ran. No account, real skill, or paid model was used. The records and reproducible harness remain the primary evidence.
