## Desync Tools and Investigations

Desync tools and desync investigations for the [Recoil](https://github.com/beyond-all-reason/RecoilEngine) engine.

### Tooling

To investigate desyncs, I had to develop some custom tools to help in running on several computers and investigating logs. These can be present around, so I'll introduce a bit here.

I run both host-player and player computers through a python script that reads the (filtered) log from the engine and sends to each other, the host can compare the log flow and notice any divergence, then prints n lines before and m lines after, and quits.
 
Both computers use `unit_autofight.lua` widget, so I don't have to click anything to reproduce and desync happens around frame 300 (I think I can cut it to earlier frame by placing attackers closer XD). I also changed startscript to not require placing commander (mode 0), so just placing commander and selecting role makes it autostarts also for the other one.
 
The "other" computer (I'm usually coding at the host) runs in a loop where it listens for host to ready up and starts the game automatically, so most of the time I don't need to go to the other computer to touch anything.

Still, the setup is very flexible since I just need to LOG_S whatever I want and can then filter and match inside python, so once an initial checksum fail is found I can keep deeping into the code and engine behaviour.

Also, since sometimes information can desync before actual desync happens, or very low occurrence desyncs can be nullified most of the time because of other conditions before they reach actual desync.
