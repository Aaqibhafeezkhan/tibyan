import os, subprocess, signal, sys, time, threading
wt='/Users/ahmed/Projects/Tibyan-wt/ad-tour'; out=sys.argv[1]; extra=sys.argv[2:]
os.makedirs(out, exist_ok=True)
env=dict(os.environ, PATH=os.path.expanduser('~/development/flutter/bin')+':'+os.environ['PATH'])
def osa(s): return subprocess.run(['osascript','-e',s],capture_output=True,text=True).stdout.strip()
def front(): return osa('tell application "System Events" to get name of first process whose frontmost is true')
def idle(): 
    o=subprocess.run("ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}'",shell=True,capture_output=True,text=True).stdout
    return float(o or 0)
p=subprocess.Popen(['flutter','test','integration_test/ad_tour_test.dart','-d','macos',*extra],cwd=wt,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
rec=None; bad=[False]; stop=[False]; log=open(os.path.join(out,'run.log'),'w')
def guard():
    while not stop[0]:
        f=front()
        if 'ibyan' not in f.lower() or idle()<0.5 and False: bad[0]=True; print('GUARD front=',f,flush=True)
        time.sleep(0.25)
for line in p.stdout:
    log.write(line); log.flush()
    if 'CLIP:start:' in line:
        name=line.split('CLIP:start:')[1].strip()
        osa('tell application "System Events" to set frontmost of (first process whose name contains "ibyan") to true'); time.sleep(0.6)
        pos=osa('tell application "System Events" to get {position, size} of window 1 of (first process whose name contains "ibyan")')
        x,y,w,h=[int(v) for v in pos.split(', ')]
        print('idle',idle(),'win',pos,flush=True)
        bad[0]=False; stop[0]=False; th=threading.Thread(target=guard); th.start()
        rec=subprocess.Popen(['ffmpeg','-y','-f','avfoundation','-capture_cursor','0','-framerate','30','-i','2:none','-vf',f'crop={w}:{h-28}:{x}:{y+28}','-pix_fmt','yuv420p','-c:v','libx264','-preset','ultrafast','-crf','12',os.path.join(out,name+'.mp4')],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    elif 'CLIP:end:' in line and rec:
        rec.send_signal(signal.SIGINT); rec.wait(); stop[0]=True; th.join()
        if bad[0]:
            os.remove(os.path.join(out,name+'.mp4')); print('DISCARDED (window not frontmost)',name,flush=True)
        else: print('ok',name,flush=True)
        rec=None
p.wait(); print('exit',p.returncode)
