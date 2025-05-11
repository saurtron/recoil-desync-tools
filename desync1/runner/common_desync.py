import subprocess
import configparser

desync_frame = False

def extract_frame(text):
    # [f=0000379] [G
    frame = text[4:text.find(b"]")]
    return int(frame)

def should_process(text):
    if not b'SyncLog' in text:
        if b'[Path]' in text:
            return True
        return False
    if b'StartMovingRaw' in text:
        return False
    #if b'P---' in text:
    #    return False
    #if b'PathDirty' in text:
    #    return False
    return True
    if b'FollowPath0' in text:
        return False
    if b'SetNextWayPoint0' in text:
        return False
    return True
    return b'SyncWay' in text or b'dead' in text or b'sync' in text or b'init:' in text

def print_data(queue, data):
    global desync_frame
    found = -1
    while found == -1:
        found = data.find(b"\n")
        if found > -1:
            text = data[data.find(b"][")+1:found+1]
            #if text.strip(b' \n') and b'SyncLog' in text and b'SyncWay' in text:
            #if text.strip(b' \n') and b'SyncLog' in text and (b'SyncWay' in text or b'dead' in text or b'sync' in text or b'init:' in text):
            if b'Desync' in text:
                desync_frame = extract_frame(text)
                print("DESYNC", text, desync_frame)
            if text.strip(b' \n') and should_process(text):
                f = extract_frame(text)
                if b'[Path]' in text:
                    if not desync_frame and f > 20000:
                        text = text.replace(b"000 ", b" ")
                        print("->", text)
                    return data[found+1:]
                text = text.replace(b"SyncWaypoints", b"SW") # <- this
                text = text.replace(b"StartMovingRaw", b"SMR")
                text = text.replace(b"UpdateTraversalPlan0", b"UTP") # <- this
                text = text.replace(b"TriggerSkipWayPoint0", b"TSW") # <- this
                text = text.replace(b"SetNextWayPoint", b"SNW")
                text = text.replace(b"FollowPath0", b"FP")

                text = text.replace(b".000", b"")
                text = text.replace(b"values:", b"")
                text = text.replace(b"float3", b"")
                if not desync_frame or f < desync_frame + 3:
                    if f > 200:
                        queue.put(text.replace(b'[SyncLog]', b''))
            data = data[found+1:]
    return data

class State:
    def __init__(self, config_file):
        self.finished = False
        self.config = self.load_config(config_file)
        self.is_host = self.config.getboolean('is_host')
    def load_config(self, config_file):
        self.configparser = configparser.ConfigParser()
        self.configparser['DEFAULT'] = {'host': '0.0.0.0',
                                        'datadir': '.',
                                        'binary': './spring',
                                        'script': '',
                                        'is_host': 'no'}
        self.configparser.read(config_file)
        return self.configparser['DEFAULT']
    def get_host(self):
        return self.config.get('host')
    def get_cmd(self):
        cmd = [self.config.get('binary'), '-isolation', '-write-dir', self.config.get('datadir'), '-fullscreen']
        if self.is_host:
            cmd += ['-server', self.get_host()]
        cmd.append(self.config.get('script'))
        print(" ".join(cmd))
        return cmd

class Runner:
    def __init__(self, queue, state):
        self.queue = queue
        self.state = state
        self.proc = None
    def kill(self):
        if self.proc:
            self.proc.kill()
    def alive(self):
        return not self.proc is None
    def run(self):
        cmd = self.state.get_cmd()
        #p = subprocess.Popen(self.cmd, stdout=subprocess.PIPE, bufsize=128, pipesize=128)
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=128000000)
        self.proc = p

        data = b""

        while not self.state.finished:
            new_data = p.stdout.read(128)
            if new_data:
                data += new_data

                if b"\n" in data:
                    data = print_data(self.queue, data)

        p.terminate()
        self.proc = None


