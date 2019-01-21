# mpv-osc

This is a fairly simple OSC server/listener for `mpv`. Pretty hacky to say the least.

## Usage

```
mpv --script=mpv-osc.lua ~/Videos/awesome-video.mp4
```

## Config

This script uses `5005` port by default but it's possible to overwrite this config:

```
--script-opts osc-port=50723
```

### VJing

Ideally, you'd like to remove audio and on-screen stuff when playing with this:

```
mpv --volume=-1 \ # mute audio
    --osd-level=0 --no-osc \ # disable on-screen stuff
    --script=mpv-osc.lua \ # the actual script
    --script-opts osc-port=50723 \ # custom options
    ~/Videos/awesome-video.mp4 # our favourite vid
```

## Addresses

Since I only needed a couple of `mpv` functions, just went for the basic stuff, such as:

* `/play`, takes no values.
* `/pause`, takes no values.
* `/toggle`, takes no values.
* `/position`, takes a single float value (from 0.0 to 100.0) that represents [playback position](https://mpv.io/manual/master/#command-interface-[relative|absolute|absolute-percent|relative-percent|exact|keyframes]).

## Examples

In SCLang format:

```
m = NetAddr.new("127.0.0.1", 5005);

(
Pdef(\mpv,
  Pbind(
    \dur, 1,
    \position, Pxrand((10,10.1..90), inf).stutter(Pwhite(1,4)),
    \play, Pfunc{ |e| m.sendMsg("/position", e.position); }
  )
)
)
Pdef(\mpv).play
Pdef(\mpv).clear
```


## LICENSE

See [LICENSE](LICENSE)
