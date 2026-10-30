#!/usr/bin/env python3
"""Generates CodeQuest's looping background music into assets/audio/music/.

Run from the project root:  python3 tools/make_music.py

Five loops, in the same dark palette as the sound effects (ADR-028): minor and
modal, detuned saw stacks rather than clean sines, saturation, and a stone room.

These are atmospheric loops, not composed pieces. That limit is honest and it is
why they are built the way they are — a pad that moves slowly under a scene is
something this approach does well; a melody a player would hum is not.

Two things make a loop actually loop:

  * **Bar-aligned length.** Every part is rendered on the same grid, so the end
    of the last bar lands exactly where the first begins.
  * **The tail is folded back.** Reverb from the final bar would otherwise be
    cut off mid-decay at the seam. The track is rendered longer than the loop
    and the overhang is added onto the opening, so the tail of the last bar
    rings over the start of the first — which is what happens on the second
    pass through anyway.
"""
import os
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music")
TAIL = 3.0                     # seconds of overhang folded back into the start

rng = np.random.default_rng(31)    # seeded: same run, same music


# --------------------------------------------------------------------------
# Toolkit
# --------------------------------------------------------------------------

def n_samples(seconds):
    return int(round(SR * seconds))


def semis(root, *steps):
    """Frequencies from a root, by semitone offsets. A chord is a tuple here."""
    return [root * (2.0 ** (s / 12.0)) for s in steps]


def lp(x, cutoff, order=4):
    """Butterworth lowpass. scipy rather than the hand-rolled one-pole in
    make_sfx: these are 30-second buffers, and a Python loop over 1.4 million
    samples four times is a minute of waiting per call."""
    b, a = signal.butter(order, min(cutoff / (SR * 0.5), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR * 0.5), 0.99), "high")
    return signal.lfilter(b, a, x)


def saw(freq, n, harmonics=18, phase=0.0):
    """Additive sawtooth, stopped below Nyquist so nothing aliases."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        f = freq * k
        if f > 13000.0:
            break
        out += np.sin(2.0 * np.pi * f * t + phase * k) / k
    return out * 0.5


def stack(freq, n, cents=(-7, 0, 9), harmonics=18):
    """The same note a few cents apart. Nothing in a room is in tune with
    itself, and the beating between these is most of what makes a pad move."""
    out = np.zeros(n)
    for i, c in enumerate(cents):
        out += saw(freq * (2.0 ** (c / 1200.0)), n, harmonics, phase=i * 0.7)
    return out / len(cents)


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def ad(n, attack, release, hold=1.0):
    """Attack-decay envelope over n samples, times in seconds."""
    a, r = n_samples(attack), n_samples(release)
    a, r = min(a, n), min(r, n)
    env = np.full(n, hold, dtype=float)
    if a:
        env[:a] = np.linspace(0.0, hold, a)
    if r:
        env[n - r:] *= np.linspace(1.0, 0.0, r)
    return env


def room(x, taps=((71, 0.30), (113, 0.23), (173, 0.17), (251, 0.11), (367, 0.07))):
    """Prime-numbered delays, so the echoes never line up into an audible pitch.
    Same reasoning as the effects' hall, done with array slicing because these
    buffers are long."""
    out = x.copy()
    for ms, gain in taps:
        d = n_samples(ms / 1000.0)
        if d >= len(x):
            continue
        shifted = np.zeros_like(x)
        shifted[d:] = x[:len(x) - d] * gain
        out += lp(shifted, 5200, order=2)
    return out


def fold_tail(x, loop_n):
    """Ring the overhang over the opening and cut to length."""
    tail = min(len(x) - loop_n, loop_n)
    if tail > 0:
        x[:tail] += x[loop_n:loop_n + tail]
    return x[:loop_n]


def seam_crossfade(stereo, ms=24.0):
    """Blend the last few milliseconds into the first, and drop them.

    Folding the reverb tail fixes the musical seam but not the arithmetic one:
    every filter in the chain starts from zero state, so sample zero is a filter
    transient rather than signal. Measured, that left the Space Map's join at
    4.5x a normal sample step — a tick, once a minute, forever.

    Two attempts at warming the filters up made it worse. This is the blunt
    version and it cannot fail: after the blend, the first sample continues
    directly from the sample that now precedes it."""
    n = n_samples(ms / 1000.0)
    if n * 2 >= len(stereo):
        return stereo
    rise = np.linspace(0.0, 1.0, n)[:, None]
    head = stereo[:n] * rise + stereo[-n:] * (1.0 - rise)
    out = stereo.copy()[:-n]
    out[:n] = head
    return out


def pad_bed(chords, bar, total_n, cents=(-7, 0, 9), cutoff=1700, level=1.0,
            octave=2.0, body=170.0):
    """One slow chord per bar, each overlapping the next so the changes breathe
    instead of stepping.

    `octave` and `body` exist because of a measurement. The first version voiced
    these chords at 110-155Hz and filtered them at 1.4-2.4kHz, and an additive
    saw puts most of its energy in the fundamental — so 95% of every track's
    energy landed below 150Hz, where a laptop speaker reproduces nothing. The
    result measured fine and was close to inaudible.

    The chords are now voiced an octave up, and highpassed so the bass line owns
    the low end alone instead of fighting a pad for it."""
    out = np.zeros(total_n)
    bar_n = n_samples(bar)
    over_n = n_samples(min(bar * 0.6, 1.6))
    for i in range(int(np.ceil(total_n / bar_n))):
        chord = [f * octave for f in chords[i % len(chords)]]
        seg_n = min(bar_n + over_n, total_n - i * bar_n)
        if seg_n <= 0:
            break
        seg = np.zeros(seg_n)
        for f in chord:
            seg += stack(f, seg_n, cents)
        seg *= ad(seg_n, bar * 0.35, bar * 0.5) / max(1, len(chord))
        out[i * bar_n:i * bar_n + seg_n] += seg
    return hp(lp(out, cutoff), body, order=4) * level


def bass_line(roots, bar, total_n, per_bar=1, level=1.0, punch=0.02):
    out = np.zeros(total_n)
    step = n_samples(bar / per_bar)
    for i in range(int(np.ceil(total_n / step))):
        f = roots[(i // per_bar) % len(roots)]
        seg_n = min(step, total_n - i * step)
        if seg_n <= 0:
            break
        t = np.arange(seg_n) / SR
        # No sub-octave. It used to add a sine an octave below the root, which
        # put fundamentals at 27-39Hz — inaudible on a laptop, and loud enough
        # in the spectrum to be most of the track's energy.
        seg = np.sin(2.0 * np.pi * f * t) + saw(f, seg_n, 10) * 0.6
        seg *= ad(seg_n, punch, bar / per_bar * 0.55)
        out[i * step:i * step + seg_n] += seg
    # Filtered higher and driven harder than before: the harmonics are what
    # carry a bass note on a speaker that cannot reproduce its fundamental.
    return drive(lp(out, 1600), 2.4) * level


def bell(freq, n, decay=3.0):
    """Struck metal: inharmonic partials, the high ones dying first."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, r in enumerate((1.0, 2.01, 3.03, 4.17, 5.43)):
        out += np.sin(2.0 * np.pi * freq * r * t) * np.exp(-t * (decay + i * 2.2)) / (1 + i * 1.5)
    return out


def sprinkle(notes, total_n, count, level=0.18, decay=2.6, seed=0):
    """A handful of bell notes at bar-ish positions. Sparse on purpose: this
    plays under a screen someone is reading."""
    r = np.random.default_rng(seed)
    out = np.zeros(total_n)
    for _ in range(count):
        at = int(r.integers(0, max(1, total_n - n_samples(2.0))))
        f = float(r.choice(notes))
        seg_n = min(n_samples(2.5), total_n - at)
        out[at:at + seg_n] += bell(f, seg_n, decay) * float(r.uniform(0.6, 1.0))
    return out * level


def pluck_figure(notes, bar, total_n, per_bar=2, level=0.3, seed=0):
    """A soft woody note, repeating slowly. This is the lesson's signature and
    the reason it no longer sounds like the Space Map: bells shimmer and sit
    high, a damped pluck sits in the middle and does not draw the ear."""
    r = np.random.default_rng(seed)
    out = np.zeros(total_n)
    step = n_samples(bar / per_bar)
    for i in range(int(np.ceil(total_n / step))):
        if i % 2 == 1:                      # leave gaps; this plays under text
            continue
        seg_n = min(n_samples(bar * 0.9), total_n - i * step)
        if seg_n <= 0:
            break
        f = float(notes[int(r.integers(0, len(notes)))])
        t = np.arange(seg_n) / SR
        seg = (np.sin(2.0 * np.pi * f * t)
               + np.sin(2.0 * np.pi * f * 2 * t) * 0.3
               + np.sin(2.0 * np.pi * f * 3.01 * t) * 0.12)
        seg *= np.exp(-t * 3.2)
        out[i * step:i * step + seg_n] += seg
    return lp(out, 2600) * level


def pulse_line(freq, bar, total_n, per_bar=8, level=0.5):
    """A muted repeated note. The thing that makes a battle feel like it has a
    clock running, without a drum kit this palette does not have."""
    out = np.zeros(total_n)
    step = n_samples(bar / per_bar)
    for i in range(int(np.ceil(total_n / step))):
        seg_n = min(step, total_n - i * step)
        if seg_n <= 0:
            break
        seg = saw(freq, seg_n, 10) * ad(seg_n, 0.004, bar / per_bar * 0.8)
        if i % 2 == 1:
            seg *= 0.55                       # light swing on the off-beats
        out[i * step:i * step + seg_n] += seg
    return lp(out, 2200) * level


def band_rms(x, lo=250.0, hi=8000.0):
    """RMS of only the part a small speaker can reproduce."""
    b, a = signal.butter(4, [lo / (SR * 0.5), min(hi / (SR * 0.5), 0.99)], "band")
    y = signal.lfilter(b, a, x)
    return float(np.sqrt((y ** 2).mean()))


def finish(mono_l, mono_r, loop_n, target_band_db=-19.0, ceiling=0.92):
    """Matched on the RMS of the 250Hz-8kHz band, not on peak and not on full
    RMS either.

    Three passes at this, and the measurements are why. Peak normalisation left
    the boss loop 3dB louder than the rest. Full-spectrum RMS fixed that and
    still produced tracks reported as "barely hearable" — because a loud low
    sine dominates total energy by definition, so all five matched at -14dB
    overall while the band a laptop actually plays sat at -27dB. The effects,
    which sound right, measure -13 to -17 there.

    So the target is the band, and everything below 70Hz is removed first: it is
    energy nothing can reproduce, and it was eating the headroom that the
    audible part of the mix then had to give up."""
    # A tilt, then the cut. Removing the sub alone was not enough: the mix was
    # still low-heavy enough that raising the audible band just ran the peaks
    # into the limiter, so the band target was never actually reached. Lifting
    # everything above 500Hz by ~6dB is what lets the mids carry the level.
    def voice(x):
        x = hp(room(x), 90.0, order=3)
        return x + hp(x, 500.0, order=2)

    left = fold_tail(voice(mono_l), loop_n)
    right = fold_tail(voice(mono_r), loop_n)
    stereo = np.stack([left, right], axis=1)

    b = band_rms(stereo.mean(axis=1))
    if b > 0:
        stereo *= (10.0 ** (target_band_db / 20.0)) / b

    # Soft-clip rather than scale back down: scaling to fit a peak would undo
    # the match that was the whole point, and these are pads — a little
    # saturation on the loudest moments is inaudible.
    peak = np.max(np.abs(stereo))
    if peak > ceiling:
        stereo = np.tanh(stereo / peak * 1.4) / np.tanh(1.4) * ceiling
    return seam_crossfade(stereo)


def save(name, stereo):
    path = os.path.join(OUT, name + ".ogg")
    sf.write(path, stereo, SR, format="OGG", subtype="VORBIS")
    kb = os.path.getsize(path) // 1024
    print(f"{name + '.ogg':18} {len(stereo) / SR:5.1f}s  {kb:5d} KB")


# --------------------------------------------------------------------------
# The tracks
# --------------------------------------------------------------------------
# Every one of them is minor or modal, because the palette is (ADR-028), and
# because a major key under a game about a Bug Lord would be a joke the game is
# not making.

A2 = 110.0


def title():
    """The menu. Wide, slow and unhurried — it plays while nothing is
    happening, so it must be able to play for a long time without nagging.
    D minor: i - VI - III - VII."""
    bar, bars = 4.0, 8
    loop_n = n_samples(bar * bars)
    total = loop_n + n_samples(TAIL)

    d, bb, f, c = A2 * 2 ** (5 / 12), A2 * 2 ** (1 / 12), A2 * 2 ** (8 / 12), A2 * 2 ** (3 / 12)
    chords = [semis(d, 0, 3, 7, 12), semis(bb, 0, 4, 7, 12),
              semis(f, 0, 4, 7, 11), semis(c, 0, 4, 7, 10)]
    roots = [d / 2, bb / 2, f / 2, c / 2]

    pad_l = pad_bed(chords, bar, total, (-9, 0, 7), 2600, 1.0, octave=2.0)
    pad_r = pad_bed(chords, bar, total, (-6, 2, 11), 2600, 1.0, octave=2.0)
    low = bass_line(roots, bar, total, 1, 0.55)
    notes = semis(d * 2, 0, 3, 5, 7, 10, 12)
    sky = sprinkle(notes, total, 10, 0.16, 2.2, seed=1)

    return finish(pad_l * 0.55 + low + sky, pad_r * 0.55 + low + sky, loop_n)


def space_map():
    """The galaxy map. Sparser and higher than the menu, with more air between
    events — it is a screen the player thinks on. A minor, i - VI - III - VII
    again but one chord every two bars, so it drifts rather than moves."""
    bar, bars = 3.5, 8
    loop_n = n_samples(bar * bars)
    total = loop_n + n_samples(TAIL)

    a, f, c, g = A2, A2 * 2 ** (8 / 12), A2 * 2 ** (3 / 12), A2 * 2 ** (10 / 12)
    chords = [semis(a, 0, 7, 12, 15), semis(a, 0, 7, 12, 15),
              semis(f, 0, 7, 12, 16), semis(f, 0, 7, 12, 16),
              semis(c, 0, 7, 12, 16), semis(c, 0, 7, 12, 16),
              semis(g, 0, 7, 12, 14), semis(g, 0, 7, 12, 14)]
    roots = [a / 2, a / 2, f / 2, f / 2, c / 2, c / 2, g / 2, g / 2]

    pad_l = pad_bed(chords, bar, total, (-8, 0, 6), 3400, 1.0, octave=2.0)
    pad_r = pad_bed(chords, bar, total, (-5, 3, 10), 3400, 1.0, octave=2.0)
    low = bass_line(roots, bar, total, 1, 0.42, punch=0.05)
    notes = semis(a * 4, 0, 3, 5, 7, 10, 12, 15)
    stars = sprinkle(notes, total, 22, 0.20, 3.4, seed=2)

    return finish(pad_l * 0.5 + low + stars, pad_r * 0.5 + low + stars, loop_n)


def lesson():
    """Under Sifu. The quietest thing here by a distance, and deliberately the
    least eventful — it plays under text somebody is reading, and music that
    asks for attention while you read is music that stops you reading.

    Rebuilt once. The first version shared the Space Map's bell sprinkles and a
    closely related key, and the two measured 0.84 alike in spectral shape —
    which is to say they sounded like the same piece. This one is in C minor
    rather than D, sits lower, and its signature is a damped wooden pluck: bells
    shimmer and pull the ear up, a pluck stays in the middle and lets go."""
    bar, bars = 5.0, 8
    loop_n = n_samples(bar * bars)
    total = loop_n + n_samples(TAIL)

    c, ab = A2 * 2 ** (3 / 12), A2 * 2 ** (11 / 12) / 2
    chords = [semis(c, 0, 3, 7, 10), semis(c, 0, 3, 7, 10),
              semis(c, 0, 3, 7, 10), semis(c, 0, 3, 7, 10),
              semis(ab, 0, 4, 7, 11), semis(ab, 0, 4, 7, 11),
              semis(ab, 0, 4, 7, 11), semis(ab, 0, 4, 7, 11)]
    roots = [c / 2] * 4 + [ab / 2] * 4

    pad_l = pad_bed(chords, bar, total, (-6, 0, 5), 2300, 1.0, octave=2.0)
    pad_r = pad_bed(chords, bar, total, (-4, 1, 8), 2300, 1.0, octave=2.0)
    low = bass_line(roots, bar, total, 1, 0.42, punch=0.12)
    wood = pluck_figure(semis(c * 2, 0, 3, 7, 10, 12), bar, total, 2, 0.26, seed=11)

    return finish(pad_l * 0.52 + low + wood, pad_r * 0.52 + low + wood, loop_n)


def battle():
    """A General fight. The only track with a clock in it: a repeating eighth
    note that never stops, which is what makes a timer feel like a timer even in
    the fights that have no timer. E minor, two chords, tight."""
    bar, bars = 2.0, 8
    loop_n = n_samples(bar * bars)
    total = loop_n + n_samples(TAIL)

    e, c = A2 * 2 ** (7 / 12), A2 * 2 ** (3 / 12)
    chords = [semis(e, 0, 3, 7, 10), semis(e, 0, 3, 7, 10),
              semis(c, 0, 4, 7, 11), semis(c, 0, 4, 7, 11),
              semis(e, 0, 3, 7, 10), semis(e, 0, 3, 7, 10),
              semis(c, 0, 4, 7, 11), semis(c, 0, 4, 7, 14)]
    roots = [e / 2, e / 2, c / 2, c / 2, e / 2, e / 2, c / 2, c / 2]

    pad_l = pad_bed(chords, bar, total, (-10, 0, 8), 3000, 1.0, octave=2.0)
    pad_r = pad_bed(chords, bar, total, (-7, 3, 12), 3000, 1.0, octave=2.0)
    low = bass_line(roots, bar, total, 2, 0.75, punch=0.006)
    tick = pulse_line(e * 2, bar, total, 8, 0.34)

    left = drive(pad_l * 0.42 + low + tick, 1.4)
    right = drive(pad_r * 0.42 + low + tick * 0.9, 1.4)
    return finish(left, right, loop_n)


def bug_lord():
    """The encounter. Slower than the General fight, not faster — weight comes
    from things taking longer, and he is the only enemy in the game the player
    cannot out-damage.

    The root moves a tritone, which is the most unsettled interval there is and
    the reason this one never sounds like it is going to resolve."""
    bar, bars = 3.0, 8
    loop_n = n_samples(bar * bars)
    total = loop_n + n_samples(TAIL)

    eb, a = A2 * 2 ** (6 / 12), A2                    # a tritone apart
    chords = [semis(eb, 0, 3, 7, 10), semis(eb, 0, 3, 7, 10),
              semis(eb, 0, 3, 6, 10), semis(eb, 0, 3, 6, 10),
              semis(a, 0, 3, 7, 10), semis(a, 0, 3, 7, 10),
              semis(eb, 0, 1, 7, 13), semis(eb, 0, 1, 7, 13)]
    # /2, not /4. The first version put the roots at 27-39Hz, which is below
    # what a laptop speaker reproduces at all — it measured the same as the
    # others and was reported as barely audible, which it was.
    roots = [eb / 2, eb / 2, eb / 2, eb / 2, a / 2, a / 2, eb / 2, eb / 2]

    pad_l = pad_bed(chords, bar, total, (-14, 0, 11), 2600, 1.0, octave=2.0)
    pad_r = pad_bed(chords, bar, total, (-11, 4, 15), 2600, 1.0, octave=2.0)
    low = bass_line(roots, bar, total, 1, 0.85, punch=0.01)
    tick = pulse_line(eb * 2, bar, total, 4, 0.30)
    toll = sprinkle(semis(eb * 2, 0, 6, 12), total, 5, 0.26, 1.4, seed=5)

    left = drive(pad_l * 0.5 + low + tick + toll, 2.0)
    right = drive(pad_r * 0.5 + low + tick * 0.85 + toll, 2.0)
    return finish(left, right, loop_n)


TRACKS = {
    "title": title,
    "space_map": space_map,
    "lesson": lesson,
    "battle": battle,
    "bug_lord": bug_lord,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in TRACKS.items():
        save(name, fn())
    print(f"\n{len(TRACKS)} loops written to assets/audio/music/")
