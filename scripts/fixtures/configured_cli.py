#!/usr/bin/python3
"""Deterministic CLI stand-in: verifies actual adapter arguments, stdin, and config paths.
This is not a provider client and never performs network requests.
"""
import json
import os
from pathlib import Path
import sys
import uuid

args = sys.argv[1:]
provider = 'codex' if args[0] == 'exec' else 'claude'
prompt = sys.stdin.read()
def value(flag):
    return args[args.index(flag) + 1] if flag in args else None

restricted = '--ignore-user-config' in args if provider == 'codex' else '--tools' in args
if restricted:
    required = ['--ephemeral', '--ignore-user-config', 'read-only', 'features.shell_tool=false'] if provider == 'codex' else ['--no-session-persistence', '--strict-mcp-config', '--disable-slash-commands', 'dontAsk', '{"disableAllHooks":true}']
    assert all(flag in args for flag in required)
    assert 'Return one JSON object' in prompt or 'comparison' in prompt.lower()
    result = 'Restricted report: configured fixture tool was not loaded.'
    session = None
else:
    forbidden = ['--ignore-user-config', '--sandbox', 'features.shell_tool=false', '--tools', '--strict-mcp-config', '--disable-slash-commands', '--setting-sources', '--settings', '--permission-mode', '--dangerously-skip-permissions', '--dangerously-bypass-approvals-and-sandbox']
    assert not any(flag in args for flag in forbidden)
    assert 'Do not use tools' not in prompt
    if provider == 'claude':
        assert value('--permission-prompts') == 'none'
    config = Path(os.environ['CODEX_HOME' if provider == 'codex' else 'CLAUDE_CONFIG_DIR'])
    settings = json.loads((config / 'fixture-config.json').read_text())
    resumed = value('resume' if provider == 'codex' else '--resume')
    session = resumed or value('--session-id') or str(uuid.uuid4())
    saved = Path.cwd() / 'fixture-session.json'
    if resumed:
        assert json.loads(saved.read_text())['session'] == resumed
    saved.write_text(json.dumps({'session': session}))
    result = f"Configured fixture skill/tool: {Path(settings['tool_file']).read_text().strip()}"
    if 'DENIED_ACTION' in prompt:
        assert settings['allow_write'] is False
        result = 'The configured fixture policy denied writing. No file was written.'

record = {'provider': provider, 'mode': 'restricted-report' if restricted else 'configured-conversation', 'arguments': args, 'input': prompt, 'output': result, 'session': session, 'cwd': str(Path.cwd())}
with open(os.environ['MSGBLAST_CLI_FIXTURE_LOG'], 'a') as log:
    log.write(json.dumps(record) + '\n')
if provider == 'codex':
    Path(value('--output-last-message')).write_text(result)
    if session:
        print(json.dumps({'type': 'thread.started', 'thread_id': session}))
        print(json.dumps({'type': 'turn.completed'}))
else:
    output = {'result': result, 'is_error': False, 'session_id': session}
    if not restricted and 'DENIED_ACTION' in prompt:
        output['permission_denials'] = [{'tool_name': 'Write'}]
    print(json.dumps(output))
