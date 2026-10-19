import os, subprocess, signal, sys, time
wt = '/Users/ahmed/Projects/Tibyan-wt/ad-tour'
out = sys.argv[1]; dev = sys.argv[2]; extra = sys.argv[3:]
os.makedirs(out, exist_ok=True)
env = dict(os.environ, PATH=os.path.expanduser('~/development/flutter/bin') + ':' + os.environ['PATH'])
p = subprocess.Popen(['flutter', 'test', 'integration_test/ad_tour_test.dart', '-d', dev, *extra],
                     cwd=wt, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
rec = None
log = open(os.path.join(out, 'run.log'), 'w')
for line in p.stdout:
    log.write(line); log.flush()
    if 'CLIP:start:' in line:
        name = line.split('CLIP:start:')[1].strip()
        rec = subprocess.Popen(['xcrun', 'simctl', 'io', dev, 'recordVideo', '--codec=h264', '--force',
                                os.path.join(out, name + '.mp4')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print('rec', name, flush=True)
    elif 'CLIP:end:' in line and rec:
        rec.send_signal(signal.SIGINT); rec.wait(); rec = None
        print('done', line.strip(), flush=True)
    elif 'EXCEPTION' in line or 'Some tests failed' in line or 'All tests passed' in line:
        print(line.strip(), flush=True)
p.wait(); print('exit', p.returncode)
