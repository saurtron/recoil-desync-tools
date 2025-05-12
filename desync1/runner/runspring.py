from queue import Queue
import common_desync

print("Started")

state = common_desync.State('runspring-host.ini')
queue = Queue()

def run_spring():
    r = common_desync.Runner(queue, state)
    r.run()


import socket
import threading

class ThreadedServer(object):
    def __init__(self, host, port):
        self.lasttext = []
        self.problem = False
        self.ok = 0
        self.extra = 100
        self.host = host
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((self.host, self.port))

    def listen(self):
        self.sock.listen(5)
        while True:
            client, address = self.sock.accept()
            client.settimeout(60)
            threading.Thread(target = self.listenToClient,args = (client,address)).start()

    def check_data(self, data):
        found = data.find(b"\n")
        while found > -1:
            text = data[:found+1]
            if text.strip(b' \n'):
                self.check_line(text)
            data = data[found+1:]
            found = data.find(b"\n")
        return data

    def check_line(self, data):
        nextdata = queue.get()
        if self.problem and self.extra > 0:
            print(" extra:", data)
            self.extra -= 1
            return
        if self.problem:
            state.finished = True
        if data == nextdata:
            #print("GOOD DATA", data)
            self.lasttext.append(data)
            if len(self.lasttext) > 3:
                self.lasttext.pop(0)
            self.ok += 1
            if self.ok % 100 == 0:
                if common_desync.desync_frame:
                    print("-k", self.ok, common_desync.extract_frame(data))
                else:
                    print("ok", self.ok, common_desync.extract_frame(data))
            #if b'dead' in nextdata:
            #    print(nextdata)
        else:
            nlines = 100
            if not self.problem:
                print("problem at:")
                for t in self.lasttext:
                    print("  prev: ", t)
                print("  other:", data)
                print("  mine: ", nextdata)
                while not queue.empty() and nlines > 0:
                    print("  next: ", queue.get())
                    nlines -= 1
            self.problem = True
        #client.send(response)

    def listenToClient(self, client, address):
        size = 512
        data = b''
        while not state.finished:
            try:
                data += client.recv(size)
                if data:
                    data = self.check_data(data)
                else:
                    raise error('Client disconnected')
            except:
                client.close()
                return False

def server_loop(port_num):
    ThreadedServer('', port_num).listen()

if __name__ == "__main__":
    port_num = 8555
    t = threading.Thread(target=server_loop, args = (port_num,))
    t.daemon = True
    t.start()
    run_spring()
