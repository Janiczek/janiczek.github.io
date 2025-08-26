# HP M479 unofficial cartridge

> TL;DR: turn off automatic updates then flash [an older firmware](http://ftp.hp.com/pub/softlib/software13/fw-recover/M478-M479_MA/HP_Color_LaserJet_Pro_MFP_M478-M479_series_FW_002_1916A.ful2) via LPR [over the network](https://www.reddit.com/r/printers/comments/tth0e4/comment/luxki98/).

> TL;DR 2: Buy a [Brother](https://global.brother/en).

I'm writing this post to help the next poor sod who wants to install an unofficial cartridge into their HP printer.

It started giving me the "Non-HP Chip Detected" error and refused to print anything from that point on.

All the usual tips that said I should turn the printer off, pull the plug, wait a minute and then turn it on, or that I should press the power-off button for 30s or more -- none of that worked. The error was still there.

I tried futzing around with "Cartridge Policy" (which explicitly said it would allow non-HP cartridges) and that didn't work either.

In the end I opted to flashing an older firmware. Thanks to [a Reddit post](https://www.reddit.com/r/printers/comments/19aqimz/comment/lvfhh6a/) I was able to find an official HP download URL (instead of some shady 3rd party website):

**http://ftp.hp.com/pub/softlib/software13/fw-recover/M478-M479_MA/HP_Color_LaserJet_Pro_MFP_M478-M479_series_FW_002_1916A.ful2**

Then I tried putting that on an USB stick and flashing the printer that way. Didn't work, the back USB port resulted in the printer trying to format the flash drive, and the front USB port tried to find something to print on the drive.

Thanks to [_another_ Reddit post](https://www.reddit.com/r/printers/comments/tth0e4/comment/luxki98/) I was able to find an alternative way to flash the printer: through the [LPR protocol](https://en.wikipedia.org/wiki/Line_Printer_Daemon_protocol).

I needed to install the `lpr` utility via "Turn Windows Features on or off" then run the following in the commandline:

```
lpr -S 192.168.8.109 -P 192.168.8.109 HP_Color_LaserJet_Pro_MFP_M478-M479_series_FW_002_1916A.ful2
```

After the command finished, it looked like nothing's happening but then the printer restarted and started installing the firmware. After that all was done, the error was gone and my printer started printing again!
