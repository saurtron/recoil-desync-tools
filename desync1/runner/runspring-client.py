import time
from queue import Queue
import common_desync

connected = False
runner = None

print("Started")

state = common_desync.State('runspring-client.ini')
queue = Queue()

def run_spring():
    global runner
    tries = 10
    while not connected and tries > 0:
        time.sleep(0.5)
        tries -= 1
    if connected:
        runner = common_desync.Runner(queue, state)
        runner.run()
    return

import socket
import threading

def client_loop(port_num):
    global connected
    socket.timeout = 3
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(3)
        try:
            s.connect((state.get_host(), port_num))
            connected = True
            print("CONNECTED")
            while not state.finished:
                elmt = queue.get()
                s.sendall(elmt)
        except ConnectionRefusedError:
            state.finished = True
        except BrokenPipeError:
            state.finished = True
        except ConnectionResetError:
            state.finished = True

if __name__ == "__main__":
    port_num = 8555
    t = threading.Thread(target=run_spring)
    t.daemon = True
    t.start()
    #if connected:
    #run_spring()
    client_loop(port_num)
    if runner and runner.alive():
        time.sleep(5)
        runner.kill()
    print("FINISH")
