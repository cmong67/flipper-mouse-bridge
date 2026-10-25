"""Exercise real executable startup while another process holds the controller lock.

Only read-only modes, invalid arguments, and owner-rejected live startup are used.
No Bluetooth connection or mouse input is requested by a passing test.
"""
import fcntl
import pathlib
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())
lock_path = pathlib.Path.home() / 'Library/Application Support/FlipperMouseBridge/controller.lock'
lock_path.parent.mkdir(parents=True, exist_ok=True)

def run(args):
    return subprocess.run([exe, *args], input='', capture_output=True, text=True, timeout=15)

with lock_path.open('a+b') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    invalid = [
        ['--cli', '--dashboard-preview'], ['--dashboard-preview', '--cli', 'Codex'],
        ['--cli', 'Codex', '--dashboard-preview'], ['--render-dashboard'],
        ['--render-dashboard', '--cli'], ['--render-dashboard', 'relative.png'],
        ['--cli', ''], ['--cli', '  '], ['--unknown'], ['Codex'],
        ['--self-test', '--cli'], ['--help', '--cli'], ['--version', 'extra'],
        ['--cli', 'Codex', 'extra'], ['--dashboard-preview', 'extra'],
        ['--render-dashboard', '/tmp/test.png', '--cli'],
    ]
    for args in invalid:
        result = run(args)
        assert result.returncode == 64, (args, result)
        assert 'Usage:' in result.stderr and 'Bluetooth' not in result.stdout and 'State:' not in result.stdout
    for args in [[], ['--cli'], ['--cli', 'NoSuchFlipper-Invocation-Test']]:
        result = run(args)
        assert result.returncode == 2 and 'Another bridge controller' in result.stderr, result
        assert 'State:' not in result.stdout
    for flag in ['--help', '-h', '--version', '--self-test']:
        result = run([flag])
        assert result.returncode == 0 and result.stdout and 'State:' not in result.stdout, result
    assert '0.4.4' in run(['--version']).stdout
    with tempfile.TemporaryDirectory() as temp:
        output = pathlib.Path(temp) / 'preview.png'
        result = run(['--render-dashboard', str(output)])
        assert result.returncode == 0 and output.read_bytes().startswith(b'\x89PNG'), result
        result = run(['--render-dashboard', str(pathlib.Path(temp) / 'missing' / 'preview.png')])
        assert result.returncode == 3 and 'Render failed:' in result.stderr, result
print('PASS: 16 invalid invocations, 3 owner rejections, 4 read-only modes, render and render failure; no live initialization')
