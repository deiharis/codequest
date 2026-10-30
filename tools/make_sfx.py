#!/usr/bin/env python3
"""Generates CodeQuest's sound effects into assets/audio/sfx/.

Run from the project root:  python3 tools/make_sfx.py

Synthesised rather than downloaded, for the same reason the arena backdrops and
the Space Map nebulae are: the licence is not a question, the result matches the
game rather than a library's idea of "sword hit", and any of them can be retuned
by editing one number here instead of hunting for a replacement file.

The palette is dark fantasy, not arcade. That distinction is made by four
choices, applied throughout:

  * **Inharmonic partials, not integer ones.** A bell whose overtones are 2x
    and 3x the root sounds like a toy. Ratios like 1.41 and 2.57 sound like
    struck metal, because struck metal is not a harmonic oscillator.
  * **Minor and modal intervals.** The victory sting is a root-fifth-octave
    climb, which reads as heroic; a major third reads as cheerful.
  * **Saturation on everything tonal.** Clean sines are a synthesiser. Driven
    ones are an instrument in a room.
  * **Low end over high shimmer, and long tails.** Everything is voiced roughly
    an octave below where it started, in a hall rather than a booth.

44.1kHz, 16-bit, mono.
"""
import math, os, struct, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")

rng = np.random.default_rng(7)   # seeded: the same run gives the same files


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(freq, dur, phase=0.0):
    """freq may be a scalar or an array the same length as the output."""
    time = t(dur)
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * time + phase)
    # Swept: integrate the instantaneous frequency so the phase stays continuous.
    return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def env(dur, attack=0.005, decay=None, power=2.0):
    """Percussive envelope: fast attack, exponential-ish decay."""
    n = int(SR * dur)
    a = max(1, int(SR * attack))
    out = np.ones(n)
    out[:a] = np.linspace(0, 1, a)
    body = np.linspace(0, 1, n - a)
    out[a:] = (1 - body) ** power
    return out


def lowpass(x, cutoff, poles=1):
    """One-pole lowpass, optionally cascaded.

    One pole is -6dB/octave, which is barely a filter: noise lowpassed at 600Hz
    still has plenty of energy at 5kHz, and the result measures — and sounds —
    far brighter than intended. Measured it: the "low breath" hover sound came
    out with a spectral centroid of 4.2kHz. `poles=4` is -24dB/octave and
    actually dark."""
    a = math.exp(-2 * math.pi * cutoff / SR)
    out = x
    for _ in range(poles):
        y = np.empty_like(out)
        prev = 0.0
        for i, v in enumerate(out):
            prev = (1 - a) * v + a * prev
            y[i] = prev
        out = y
    return out


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def svf(x, cutoff, q=4.0, mode="band"):
    """Chamberlin state-variable filter. Two poles with resonance, and `cutoff`
    may be an array — which is the whole point. A blade passing your ear is a
    resonant peak sliding down the spectrum; a fixed filter cannot make that
    sound, and neither can the one-pole lowpass above."""
    n = len(x)
    cut = np.full(n, cutoff, dtype=float) if np.isscalar(cutoff) else np.asarray(cutoff)[:n]
    f = 2.0 * np.sin(np.pi * np.clip(cut, 20, SR * 0.45) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty(n)
    for i in range(n):
        high = x[i] - low - damp * band
        band = band + f[i] * high
        low = low + f[i] * band
        out[i] = band if mode == "band" else (low if mode == "low" else high)
    return out


def sweep(f0, f1, dur):
    """Frequency array going f0 -> f1 over dur, for sine()."""
    return np.linspace(f0, f1, int(SR * dur))


def pad(x, dur):
    n = int(SR * dur)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def reverb(x, delay=0.045, decay=0.3, taps=4):
    """Fading echoes. Not a real reverb — enough to stop a sound sounding like
    it happened inside the speaker."""
    out = x.copy()
    d = int(SR * delay)
    for i in range(1, taps + 1):
        shifted = np.zeros_like(out)
        shifted[d * i:] = x[:len(x) - d * i] * (decay ** i)
        out += shifted
    return out


def hall(x, tail=1.1):
    """A stone room. Prime-numbered delays so the echoes never line up into an
    audible pitch, plus a smeared noise tail. Everything in this game happens
    somewhere large and unpleasant; this is what says so."""
    x = pad(x, len(x) / SR + tail)
    out = x.copy()
    for ms, g in [(37, 0.34), (53, 0.26), (79, 0.19), (113, 0.13),
                  (167, 0.09), (233, 0.06), (313, 0.04)]:
        d = int(SR * ms / 1000)
        shifted = np.zeros_like(out)
        shifted[d:] = x[:len(x) - d] * g
        out += lowpass(shifted, 4500)
    return out


def drive(x, amount=3.0):
    """Saturation. The single biggest difference between a sound that reads as
    a synthesiser and one that reads as an object being struck."""
    return np.tanh(x * amount) / math.tanh(amount)


def metal(root, dur, ratios=(1.0, 1.41, 1.93, 2.57, 3.11), decay=3.0, spread=0.004):
    """Struck metal. Inharmonic ratios, each partial decaying at its own rate —
    the high ones die first, which is what makes it a strike rather than a pad.
    `spread` detunes each partial slightly so it beats instead of sitting still."""
    out = np.zeros(int(SR * dur))
    for i, r in enumerate(ratios):
        f = root * r * (1 + rng.uniform(-spread, spread))
        amp = 1.0 / (1 + i * 1.4)
        out += sine(f, dur) * env(dur, 0.001, power=decay + i * 1.1) * amp
    return out


def saw(freq, dur, partials=10):
    """Band-limited sawtooth. Brass and drones are built from this, not sines —
    a sine has nothing for the saturation to bite on."""
    out = np.zeros(int(SR * dur))
    for k in range(1, partials + 1):
        f = freq * k if np.isscalar(freq) else freq * k
        out += sine(f, dur) / k
    return out * 0.5


def stack(freq, dur, cents=(-9, 0, 11)):
    """The same note three times, detuned by a few cents. Nothing in a real room
    is perfectly in tune with itself."""
    return sum(saw(freq * (2 ** (c / 1200.0)), dur) for c in cents) / len(cents)


def finish(x, peak=0.85):
    # Normalise BEFORE clipping, not after. Clipping a signal that is already
    # loud is distortion, not limiting: it folds a 40Hz rumble into a spray of
    # harmonics and the "low boom" comes out sounding bright and fizzy. Measured
    # it — the Bug Lord's arrival had a spectral centroid of 1.9kHz before this.
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * 0.9
    x = np.tanh(x * 1.05) / math.tanh(1.05)   # gentle, only touches the peaks
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    # Trim the inaudible end of the hall tail. Without this every file carries
    # half a second of -70dB nothing, which is disk, decode time and nothing else.
    loud = np.abs(x) > 0.001                      # about -60dBFS
    if loud.any():
        x = x[:np.max(np.nonzero(loud)) + 1]

    # 5ms fade out so nothing ends on a click
    f = min(len(x), int(SR * 0.005))
    x[-f:] *= np.linspace(1, 0, f)
    return x


def save(name, x):
    x = finish(x)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name + '.wav':22} {len(x) / SR:.2f}s")


# --------------------------------------------------------------------------
# The sounds
# --------------------------------------------------------------------------

def sword_hit():
    """A greatsword slice. Three parts in this order and no other: the blade
    passing (a resonant band sliding down), the edge biting (a hard bright
    transient), and only then the mass behind it.

    The first dark pass got this wrong by filtering the highs out, which made it
    a club. A cut is defined by what happens in the first 20 milliseconds above
    2kHz. The low end is the weight; the high end is the edge."""
    d = 0.75
    whoosh_d = 0.20
    air = svf(noise(whoosh_d), sweep(5200, 900, whoosh_d), q=7.0)
    n_up = int(SR * whoosh_d * 0.55)
    air *= np.concatenate([np.linspace(0, 1, n_up) ** 2,
                           np.linspace(1, 0, int(SR * whoosh_d) - n_up)])
    air *= 1.5

    bite_d = 0.5
    edge = highpass(noise(0.03), 4200) * env(0.03, 0.0002, power=6) * 1.6
    shing = metal(760, bite_d, ratios=(1.0, 1.52, 2.11, 2.96, 3.91, 5.2), decay=5.5) * 1.1
    ring = metal(1520, 0.3, ratios=(1.0, 1.47, 2.09), decay=7.0) * 0.5
    thunk = sine(sweep(260, 80, 0.18), 0.18) * env(0.18, 0.001, power=3.2) * 0.75
    bite = mix(pad(edge, bite_d), shing, pad(ring, bite_d), pad(thunk, bite_d))

    lead = int(SR * 0.15)
    core = mix(pad(air, d), np.concatenate([np.zeros(lead), pad(bite, d - 0.15)]))
    return hall(drive(core, 1.5), 0.45) * 0.95


def enemy_hit():
    """You, being cut. The same shape as the hero's swing — it is a blade too —
    but pitched down, wetter and slower, with the impact carrying flesh and bone
    instead of armour. Still sharp: if this one thuds, the player reads it as a
    punch and the General stops being armed."""
    d = 0.95
    whoosh_d = 0.26
    air = svf(noise(whoosh_d), sweep(2800, 420, whoosh_d), q=6.0)
    n_up = int(SR * whoosh_d * 0.6)
    air *= np.concatenate([np.linspace(0, 1, n_up) ** 2,
                           np.linspace(1, 0, int(SR * whoosh_d) - n_up)])
    air *= 1.3

    hit_d = 0.65
    edge = highpass(noise(0.025), 2600) * env(0.025, 0.0003, power=5) * 1.5
    tear = svf(noise(0.16), sweep(2200, 380, 0.16), q=3.0) * env(0.16, 0.001, power=4) * 1.7
    # Same correction as boss_arrive: the sub-heavy body was 15dB louder than
    # anything a laptop speaker could reproduce, so the cut was inaudible on it.
    body_ = sine(sweep(150, 36, hit_d), hit_d) * env(hit_d, 0.001, power=2.2) * 0.8
    crunch = lowpass(noise(0.25), 700, poles=3) * env(0.25, 0.001, power=5) * 1.1
    sour = (sine(82, hit_d) + sine(86.8, hit_d)) * env(hit_d, 0.01, power=2.4) * 0.3
    hit = mix(pad(edge, hit_d), pad(tear, hit_d), body_, pad(crunch, hit_d), sour)

    lead = int(SR * 0.18)
    core = mix(pad(air, d), np.concatenate([np.zeros(lead), pad(hit, d - 0.18)]))
    return hall(drive(core, 2.0), 0.6)


def answer_correct():
    """Correct. Deliberately the OPPOSITE of `answer_wrong` on every axis a
    listener uses to tell two sounds apart, because the first version differed
    only in pitch and the two read as the same event:

        rhythm     one strike            vs  two fast stabs
        direction  rising                vs  falling
        length     rings for over a sec  vs  dead in a third of one
        texture    clean resonant metal  vs  buzzing driven cluster
        space      long hall             vs  dry

    Pitch alone is not a difference. Rhythm is."""
    d = 1.5
    first = metal(330.0, d, ratios=(1.0, 2.02, 3.04, 4.1), decay=1.8, spread=0.002)
    up = metal(494.0, d - 0.18, ratios=(1.0, 2.01, 3.05), decay=2.0, spread=0.002) * 0.7
    second = np.concatenate([np.zeros(int(SR * 0.18)), up])
    shimmer = highpass(noise(0.08), 6000) * env(0.08, 0.001, power=4) * 0.1
    core = drive(mix(first, second, pad(shimmer, d)) * 0.75, 1.25)
    return hall(core, 1.1) * 0.85


def answer_wrong():
    """Wrong. Two fast stabs, falling, dry, and over almost before it starts.
    See `answer_correct` for why each of those is deliberate.

    Nothing here rings. A tail would make it sound like a note, and this is not
    supposed to be music."""
    out = np.zeros(int(SR * 0.42))
    for i, (start, root) in enumerate([(0.0, 138.6), (0.105, 116.5)]):
        sd = 0.20
        cluster = (stack(root, sd, (-9, 0, 7))
                   + stack(root * 1.059, sd, (0,)) * 0.9      # minor 2nd against it
                   + saw(root * 4.0, sd) * 0.45)              # buzz, so it carries
        cluster *= env(sd, 0.002, power=3.2)
        thud = sine(sweep(root, root * 0.42, 0.16), 0.16) * env(0.16, 0.001, power=3.5)
        seg = drive(mix(cluster * 0.6, pad(thud, sd)), 4.5) * (1.0 - i * 0.18)
        at = int(SR * start)
        out[at:at + len(seg)] += seg[:len(out) - at]
    return reverb(out, 0.022, 0.16, 2) * 0.95


def ultimate():
    """The Ultimate. A drone that climbs and distorts, then a crash. The only
    sound here allowed past a second, and the only one that uses the whole
    range."""
    cd = 0.75
    climb = stack(sweep(55, 220, cd), cd, (-11, 0, 13))
    climb *= np.linspace(0.05, 1.0, int(SR * cd))
    climb = drive(climb, np.e)  # bites harder as it gets louder
    rise = sine(sweep(300, 1200, cd), cd) * np.linspace(0.0, 0.14, int(SR * cd))
    lead = mix(climb * 0.7, rise)

    hd = 1.1
    boom = sine(sweep(120, 32, hd), hd) * env(hd, 0.001, power=2.0) * 1.6
    crash = metal(310, hd, ratios=(1.0, 1.37, 1.88, 2.44, 3.29, 4.13), decay=2.2)
    blast = lowpass(noise(0.45), 1400, poles=2) * env(0.45, 0.001, power=4) * 0.9
    impact = drive(mix(boom, crash * 0.8, pad(blast, hd)), 2.6)

    return np.concatenate([lead, hall(impact, 1.3)])


def victory():
    """Root, fifth, octave — a power-chord climb, no third in it at all. A major
    third is what made the first version sound like a mobile game. Brass-ish saw
    stacks over a low drone, in a hall."""
    notes = [(146.83, 0.00), (220.0, 0.16), (293.66, 0.32)]   # D3 A3 D4
    parts = []
    for f, start in notes:
        d = 1.35 - start
        tone = stack(f, d) * env(d, 0.02, power=1.5)
        tone += stack(f * 2, d) * env(d, 0.015, power=2.6) * 0.3
        parts.append(np.concatenate([np.zeros(int(SR * start)), tone]))
    drone = stack(73.42, 1.35, (-6, 0, 8)) * env(1.35, 0.05, power=1.2) * 0.5
    core = drive(mix(*parts, drone) * 0.5, 2.2)
    return hall(core, 1.1) * 0.9


def defeat():
    """The same shape inverted and soured — a fall to a minor second that beats
    against itself, over a dying rumble. They should be recognisable as a pair."""
    notes = [(174.61, 0.00), (138.59, 0.35), (103.83, 0.70)]  # F3, C#3, G#2
    parts = []
    for f, start in notes:
        d = 2.0 - start
        tone = (stack(f, d, (-13, 0, 9)) + saw(f * 1.06, d) * 0.3)
        parts.append(np.concatenate([np.zeros(int(SR * start)), tone * env(d, 0.04, power=1.3)]))
    rumble = sine(sweep(60, 28, 2.0), 2.0) * env(2.0, 0.1, power=1.4) * 0.8
    core = drive(mix(*parts, rumble) * 0.45, 1.9)
    return hall(core, 1.3) * 0.9


def ui_click():
    """Wood and stone, not plastic. Lowpassed hard so it sits under everything
    — this plays more often than any other sound in the game."""
    d = 0.09
    knock = lowpass(noise(d), 900, poles=3) * env(d, 0.0004, power=8)
    tone = (sine(520, d) + sine(310, d) * 0.6) * env(d, 0.0004, power=7) * 0.8
    return drive(mix(knock * 0.8, tone), 1.6) * 0.5


def ui_hover():
    """A soft tick under the cursor.

    The previous one was voiced at 165Hz and was reported inaudible, which was
    correct: laptop speakers roll off hard below about 200Hz, so a quiet 0.1s
    sound down there does not exist for most players. Soft has to mean low in
    LEVEL, not low in PITCH. This sits at 880Hz, where anything can reproduce
    it, and stays quiet by being short and gently enveloped."""
    d = 0.09
    tone = (sine(880, d) + sine(1320, d) * 0.3) * env(d, 0.006, power=4) * 0.5
    breath = svf(noise(d), 1500, q=1.5) * env(d, 0.004, power=5) * 0.25
    return mix(tone, breath) * 0.6


def boss_arrive():
    """The Bug Lord rising.

    Also reported inaudible, and for the same reason as the hover: it was a
    26-55Hz sweep, which a laptop speaker cannot reproduce at all. The sub stays
    — it is what a player with headphones or a subwoofer feels — but the sound
    now carries in the 200Hz-2kHz band, where every speaker works.

    The trick is saturation. Driving a low saw stack hard generates a harmonic
    series above the fundamental, and the ear reconstructs the missing bass from
    it. That is how a small speaker conveys something enormous."""
    d = 2.4
    ramp = np.linspace(0, 1, int(SR * d))

    # Balance measured, not guessed: only 5% of this sound's energy landed in
    # the 250Hz-8kHz band a laptop speaker can reproduce, so the sub and the
    # rumble were carrying it and nobody could hear it. They are now support.
    sub = sine(sweep(30, 58, d), d) * (0.3 + 0.7 * ramp) * 0.45
    horn = (stack(116.0, d, (-12, 0, 10)) + stack(123.5, d, (0,)) * 0.75
            + stack(58.0, d, (0,)) * 0.5)
    horn = drive(horn * (ramp ** 1.5), 6.0) * 1.7
    growl = svf(noise(d), sweep(220, 1100, d), q=2.0) * (ramp ** 2) * 1.0
    rumble = lowpass(noise(d), 220, poles=4) * (0.2 + 0.8 * ramp) * 0.22
    cry = svf(noise(d), sweep(700, 2600, d), q=5.0) * (ramp ** 3) * 0.8

    core = drive(mix(sub, horn, growl, rumble, cry), 1.6)
    return hall(core, 1.2)


def panel_in():
    """The question scroll arriving. Leather and parchment unrolling, then the
    wooden rod it is wound on settling. Voiced up in the 400Hz-4kHz band where
    it will be heard over whatever else is on screen."""
    d = 0.42
    unroll = svf(noise(0.26), sweep(700, 2600, 0.26), q=2.5)
    unroll *= np.concatenate([np.linspace(0, 1, int(SR * 0.05)),
                              np.linspace(1, 0.25, int(SR * 0.26) - int(SR * 0.05))]) * 1.2
    grain = svf(noise(0.26), 1400, q=1.2) * env(0.26, 0.02, power=1.5) * 0.5
    settle = (sine(196, 0.2) + sine(293, 0.2) * 0.4) * env(0.2, 0.002, power=5) * 0.7
    at = int(SR * 0.21)
    core = mix(pad(mix(unroll, grain), d),
               np.concatenate([np.zeros(at), pad(settle, d - 0.21)]))
    return hall(drive(core, 1.4), 0.3) * 0.8


def panel_out():
    """The scroll leaving. The same materials falling instead of rising, and
    shorter — dismissal should not take as long as presentation."""
    d = 0.3
    roll = svf(noise(0.2), sweep(2400, 500, 0.2), q=2.5) * env(0.2, 0.004, power=2.0) * 1.2
    grain = svf(noise(0.18), 900, q=1.2) * env(0.18, 0.004, power=2.5) * 0.45
    return reverb(drive(mix(pad(roll, d), pad(grain, d)), 1.3), 0.03, 0.2, 2) * 0.75


def page_turn():
    """One lesson beat advancing. A paper rustle: two overlapping bursts, because
    a single burst reads as static and a page never moves at one speed."""
    d = 0.26
    out = np.zeros(int(SR * d))
    for start, f0, f1, amp in [(0.0, 2200, 4800, 1.0), (0.055, 1500, 3400, 0.7)]:
        seg_d = 0.16
        seg = svf(noise(seg_d), sweep(f0, f1, seg_d), q=1.8)
        seg *= env(seg_d, 0.006, power=2.2) * amp
        at = int(SR * start)
        out[at:at + len(seg)] += seg[:len(out) - at]
    return reverb(out, 0.02, 0.15, 2) * 0.6


def type_tick():
    """One character of Sifu's speech.

    This plays dozens of times per line, so it is 25 milliseconds long, dry, and
    deliberately thin — anything with a tail would smear into a buzz. The pitch
    jitter that AudioManager applies on every call is what stops a run of them
    sounding like a machine gun."""
    d = 0.025
    tick = highpass(noise(d), 1200) * env(d, 0.0003, power=8)
    tone = sine(1750, d) * env(d, 0.0003, power=9) * 0.5
    return mix(tick * 0.6, tone) * 0.4


def planet_hover():
    """The Space Map only. A clean glass ting.

    This is the one sound in the game that is deliberately NOT dark-fantasy.
    The Space Map is a navigation screen, not a place — it is the one surface
    where the game is software rather than a world, and a modern interface
    chime reads as correct there where a leather creak would not.

    So: pure sines, no saturation, no stone room. A near-instant attack, a high
    root with a fifth above it, and a short bright tail."""
    d = 0.3
    ting = (sine(2093.0, d)                      # C7
            + sine(3136.0, d) * 0.45             # G7, a fifth up
            + sine(4186.0, d) * 0.18)            # C8, just for air
    ting *= env(d, 0.0006, power=4.5)
    # A breath of noise on the very front, so the attack has an edge to it
    # rather than arriving as a pure tone out of nowhere.
    spark = highpass(noise(0.012), 6000) * env(0.012, 0.0002, power=6) * 0.35
    return reverb(mix(ting * 0.8, pad(spark, d)), 0.028, 0.3, 4) * 0.7


def burst():
    """The Bug Lord going up. No charge and no warning — this one starts at its
    loudest sample and falls away, which is what an explosion is and what the
    Ultimate's charge-then-boom deliberately is not."""
    d = 1.8
    crack = highpass(noise(0.04), 3000) * env(0.04, 0.0002, power=4) * 1.8
    # Same balance lesson as boss_arrive: a huge sub plus hiss measures as 6%
    # of the energy in the band a laptop can play, and comes out thin.
    boom = sine(sweep(160, 26, d), d) * env(d, 0.0008, power=1.8) * 0.85
    body_ = lowpass(noise(0.7), 900, poles=2) * env(0.7, 0.0008, power=3.0) * 1.7
    # A violet-sounding thing, if such a claim can be made: a detuned cluster
    # ringing on after the blast, so the explosion has something unnatural in it.
    shade = (stack(87.3, d, (-14, 0, 12)) + stack(123.5, d, (0,)) * 0.6)
    shade = drive(shade * env(d, 0.01, power=1.6), 4.0) * 1.1
    air = svf(noise(d), sweep(2200, 320, d), q=2.2) * env(d, 0.002, power=2.4) * 0.5
    core = drive(mix(pad(crack, d), boom, pad(body_, d), shade, air), 2.2)
    return hall(core, 1.3)


SOUNDS = {
    "sword_hit": sword_hit,
    "enemy_hit": enemy_hit,
    "answer_correct": answer_correct,
    "answer_wrong": answer_wrong,
    "ultimate": ultimate,
    "victory": victory,
    "defeat": defeat,
    "ui_click": ui_click,
    "ui_hover": ui_hover,
    "boss_arrive": boss_arrive,
    "panel_in": panel_in,
    "panel_out": panel_out,
    "page_turn": page_turn,
    "type_tick": type_tick,
    "planet_hover": planet_hover,
    "burst": burst,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        save(name, fn())
    print(f"\n{len(SOUNDS)} files written to assets/audio/sfx/")
