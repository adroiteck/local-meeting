#!/bin/bash
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./install.sh --verify
/usr/bin/python3 -m unittest discover -s tests -v
/usr/bin/sandbox-exec -f src/offline.sb /usr/bin/python3 - <<'PY'
import socket
try:
    socket.socket().connect(('1.1.1.1',443))
except PermissionError:
    print('PASS: runtime network connection denied')
else:
    raise SystemExit('FAIL: network connection permitted')
PY
DEST="$(mktemp -d /tmp/local-meeting-smoke.XXXXXX)"
/usr/bin/say -v Samantha -o "$DEST/sample.aiff" 'This is our project meeting. We decided to launch the pilot next week. Alex will deliver the security report by Friday. Maria will prepare the customer demo by Thursday. The budget approval is still blocked. We need to ask finance about the final budget.'
./meeting.sh --meeting "$DEST" --audio "$DEST/sample.aiff"
/usr/bin/python3 - "$DEST" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); items=json.loads((p/'notes.json').read_text())['items']
for owner, due, word in [('Alex','Friday','report'),('Maria','Thursday','demo')]:
    assert any(i['kind'] in ('deliverable','action') and i['owner']==owner and i['due']==due and word in i['text'].lower() for i in items), (owner,items)
assert any(i['kind']=='decision' and 'pilot' in i['text'].lower() for i in items), items
assert any(i['kind']=='blocker' and 'budget' in i['text'].lower() for i in items), items
assert (p/'transcript.txt').stat().st_size>0
print('PASS: real audio → transcript → evidence-backed deliverables, decision and blocker')
print('Synthetic test evidence: '+str(p))
PY
