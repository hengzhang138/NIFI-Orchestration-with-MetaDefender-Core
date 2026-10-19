#!/usr/bin/env bash
# Usage: bash render-nifi-v4.sh TEMPLATE VARIABLES OUTPUT [--context]
set -euo pipefail
if [[ $# -lt 3 || $# -gt 4 || ( $# -eq 4 && "$4" != "--context" ) ]]; then
  echo 'Usage: bash render-nifi-v4.sh TEMPLATE.json VARIABLES.json OUTPUT.json [--context]' >&2
  exit 2
fi
command -v python3 >/dev/null || { echo 'Python 3 is required.' >&2; exit 2; }
python3 - "$@" <<'PY'
import json, os, re, sys, tempfile
from pathlib import Path

def fail(message):
    raise ValueError(message)

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail('Duplicate JSON key: ' + key)
        result[key] = value
    return result

try:
    template, variables, output = map(Path, sys.argv[1:4])
    keep_context = len(sys.argv) == 5
    if output.resolve() in (template.resolve(), variables.resolve()):
        fail('Output must differ from template and variables files.')
    if output.exists():
        fail('Output already exists; choose a new output filename.')
    with template.open(encoding='utf-8') as f:
        flow = json.load(f, object_pairs_hook=unique_object)
    with variables.open(encoding='utf-8') as f:
        values = json.load(f, object_pairs_hook=unique_object)
    if not isinstance(values, dict):
        fail('Variables must be a JSON object of variable names and values.')
    contexts = flow.get('parameterContexts', {})
    if set(contexts) != {'Nifi-test-v4-Parameters'}:
        fail('Expected the supplied Nifi-test-v4.json parameterized template.')
    params = contexts['Nifi-test-v4-Parameters']['parameters']
    expected = {p['name'] for p in params}
    missing, unknown = expected - values.keys(), values.keys() - expected
    if missing:
        fail('Missing variables: ' + ', '.join(sorted(missing)))
    if unknown:
        fail('Unknown variables: ' + ', '.join(sorted(unknown)))
    for name, value in values.items():
        if value is None or value == '':
            fail('Fill in variable: ' + name)
        if not isinstance(value, str):
            fail('Use a JSON string for variable: ' + name)
        if '#{' in value:
            fail('Nested NiFi parameter references are not supported: ' + name)
    pattern = re.compile(r'#\{([^{}]+)\}')
    for p in params:
        p['value'] = values[p['name']]
    replacements = 0
    def visit(value):
        global replacements
        if isinstance(value, str):
            def replace(match):
                global replacements
                name = match.group(1)
                if name not in values:
                    fail('Undefined template parameter: ' + name)
                replacements += 1
                return values[name]
            return pattern.sub(replace, value)
        if isinstance(value, list):
            return [visit(item) for item in value]
        if isinstance(value, dict):
            return {key: visit(item) for key, item in value.items()
                    if key != 'parameterContextName'}
        return value
    if not keep_context:
        flow['flowContents'] = visit(flow['flowContents'])
        flow['parameterContexts'] = {}
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, staging = tempfile.mkstemp(prefix='.nifi-v4-', dir=output.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(flow, f, indent=2, ensure_ascii=False)
            f.write('\n')
        # Hard link prevents overwriting a file created concurrently.
        os.link(staging, output)
    finally:
        os.unlink(staging)
    mode = 'parameter context values updated' if keep_context else str(replacements) + ' parameter references replaced'
    print('Created ' + str(output) + ' (' + mode + ').')
    print('Output permissions: owner read/write only. Credentials are not printed.')
except (ValueError, OSError, KeyError, TypeError) as error:
    # Never include malformed JSON content or variable values in diagnostics.
    if isinstance(error, json.JSONDecodeError):
        print('Error: invalid JSON at line ' + str(error.lineno) + ', column ' + str(error.colno) + '.', file=sys.stderr)
    elif isinstance(error, OSError):
        print('Error: filesystem operation failed (' + str(error.strerror) + ').', file=sys.stderr)
    else:
        print('Error: ' + str(error), file=sys.stderr)
    sys.exit(1)
PY
