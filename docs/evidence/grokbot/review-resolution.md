# Review resolution

The full ce-code-review receipt (run `20261007-174308-d4ce51d1`) completed with seven validated findings. All were applied:

1. Quick Tunnel startup allows 90 seconds and 40 probes; the actual final-source HTTPS synthetic callback succeeded on this Mac after DNS propagation.
2. Connection loss marks both attempting and waiting requests uncertain; a later acknowledgement preserves the saved state.
3. Explicit re-enable resets disconnected readiness before reconnecting.
4. The receiver signals draining only after response-write completion; disabling after a final reply no longer closes its acknowledgement early. Actual loopback regression covers a storage failure, identical retry and acknowledgement before shutdown.
5. Received non-200 webhook responses are definitive rejection; transport failures remain ambiguous.
6. Definitive rejection removes only that request's unsent user turn from subsequent history, retaining its attempt and draft.
7. Intercepted transport tests now cover 401, 403, 404, 429, 500 and a timeout. Rejection and attempting-request loss tests failed before the fixes.

An additional runtime cleanup issue was fixed: shutdown kills only the app-owned stateless tunnel helper synchronously, so parent exit cannot discard a scheduled escalation. The final actual HTTPS check left no owned helper running; the unrelated pre-existing user service was preserved.

Simplification applied two quality and two efficiency findings. The proposed shared redirect delegate was left unchanged to avoid widening the unrelated feedback transport; each small delegate retains its domain's existing redirect rejection.

Validation: 176 native core tests, 74 Python tests and 12 feedback tests passed. Native blue demo evidence shows the actual UI with simulated webhook acceptance and callbacks. The actual public tunnel check used synthetic data and contacted no Bot. A live account's routine and credentials are not configured or validated. Grok's external review could not start because its transport requested an unavailable acpx version; the skill completed its independent local adversarial fallback. No source was sent to that peer.

Latest-main integration: merged `eaae858` after main advanced during implementation. Preserved conversation joins, private reply isolation and web receipt recovery. A focused independent integration check found that accepted Bot requests must qualify as confirmed outgoing submissions when recording explicitly shared context; `.waiting` now qualifies and `.uncertain` remains excluded. Native Bot sessions skip website sign-in and receipt-link APIs. Additional regressions cover those boundaries. No live Bot work was used.

Final latest-main validation: 201 native core tests passed, including native Bot exclusion from website sign-in/recovery and accepted shared-context submission. The actual comparison/controller fixture harness also passed join ordering, private-reply exclusion and broadcast identity checks.
