import os
import math
import struct
import wave

SAMPLE_RATE = 44100

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)

def write_wav(filename, samples, sample_rate=SAMPLE_RATE, channels=1):
    ensure_dir(os.path.dirname(filename))
    with wave.open(filename, 'wb') as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        packed_data = bytearray()
        if channels == 1:
            for s in samples:
                # Clamp between -1.0 and 1.0
                clamped = max(-1.0, min(1.0, s))
                int_val = int(clamped * 32767.0)
                packed_data.extend(struct.pack('<h', int_val))
        elif channels == 2:
            # samples is list of (left, right)
            for left, right in samples:
                cl_l = max(-1.0, min(1.0, left))
                cl_r = max(-1.0, min(1.0, right))
                packed_data.extend(struct.pack('<hh', int(cl_l * 32767.0), int(cl_r * 32767.0)))
                
        wav_file.writeframes(packed_data)
    print(f"Generated: {filename} ({len(samples)} samples, {channels} ch)")

# Pseudo-random noise generator with fixed seed for determinism
class NoiseGen:
    def __init__(self, seed=12345):
        self.state = seed
    def next(self):
        self.state = (self.state * 1103515245 + 12345) & 0x7fffffff
        return (self.state / 0x3fffffff) - 1.0 # -1.0 to 1.0

# 1. UI Sounds
def make_ui_hover():
    duration = 0.025
    total = int(duration * SAMPLE_RATE)
    out = []
    freq = 2400.0
    for i in range(total):
        t = i / SAMPLE_RATE
        env = math.exp(-i / (SAMPLE_RATE * 0.005))
        s = math.sin(2.0 * math.pi * freq * t) * env * 0.18
        out.append(s)
    return out

def make_ui_click():
    duration = 0.05
    total = int(duration * SAMPLE_RATE)
    out = []
    for i in range(total):
        t = i / SAMPLE_RATE
        env = math.exp(-i / (SAMPLE_RATE * 0.009))
        f = 500.0 + 900.0 * (1.0 - (i / total))
        s = (math.sin(2.0 * math.pi * f * t) + 0.3 * math.sin(4.0 * math.pi * f * t)) * env * 0.4
        out.append(s)
    return out

def make_ui_track_select():
    duration = 0.22
    total = int(duration * SAMPLE_RATE)
    out = []
    for i in range(total):
        t = i / SAMPLE_RATE
        if t < 0.08:
            f = 750.0
            env = min(1.0, t / 0.005) * math.exp(-t / 0.04)
        else:
            f = 1150.0
            t2 = t - 0.08
            env = min(1.0, t2 / 0.005) * math.exp(-t2 / 0.07)
        s = math.sin(2.0 * math.pi * f * t) * env * 0.4
        out.append(s)
    return out

# 2. Typing Sounds
def make_type_click():
    duration = 0.038
    total = int(duration * SAMPLE_RATE)
    out = []
    noise = NoiseGen(42)
    for i in range(total):
        t = i / SAMPLE_RATE
        env = math.exp(-i / (SAMPLE_RATE * 0.006))
        # Mechanical keystroke: high resonant ping + micro noise transient
        tone = math.sin(2.0 * math.pi * 1850.0 * t) * 0.6 + math.sin(2.0 * math.pi * 3100.0 * t) * 0.4
        ns = noise.next() * 0.35 * env
        s = (tone * env * 0.65 + ns) * 0.28
        out.append(s)
    return out

def make_type_error():
    duration = 0.12
    total = int(duration * SAMPLE_RATE)
    out = []
    for i in range(total):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.005) * (1.0 - t / duration)
        f = 140.0 - 50.0 * (t / duration)
        # Soft buzz/thud
        s = (math.sin(2.0 * math.pi * f * t) + 0.5 * math.sin(4.0 * math.pi * f * t) + 0.25 * math.sin(6.0 * math.pi * f * t)) * env * 0.35
        out.append(s)
    return out

def make_phrase_complete():
    duration = 0.45
    total = int(duration * SAMPLE_RATE)
    out = []
    notes = [523.25, 659.25, 783.99, 1046.5] # C5, E5, G5, C6
    note_len = 0.09
    for i in range(total):
        t = i / SAMPLE_RATE
        note_idx = min(int(t / note_len), len(notes) - 1)
        freq = notes[note_idx]
        note_t = t - (note_idx * note_len)
        env = min(1.0, note_t / 0.005) * math.exp(-note_t / (0.15 if note_idx == len(notes)-1 else 0.06))
        s = (math.sin(2.0 * math.pi * freq * t) + 0.25 * math.sin(4.0 * math.pi * freq * t)) * env * 0.38
        out.append(s)
    return out

# 3. Countdown & Race Start
def make_countdown_beep():
    duration = 0.18
    total = int(duration * SAMPLE_RATE)
    out = []
    freq = 880.0 # A5
    for i in range(total):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.005) * math.exp(-t / 0.07)
        s = (math.sin(2.0 * math.pi * freq * t) + 0.2 * math.sin(4.0 * math.pi * freq * t)) * env * 0.45
        out.append(s)
    return out

def make_race_start():
    duration = 0.50
    total = int(duration * SAMPLE_RATE)
    out = []
    f1 = 1760.0 # A6
    f2 = 2217.46 # C#7
    for i in range(total):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.005) * math.exp(-t / 0.18)
        s = (math.sin(2.0 * math.pi * f1 * t) * 0.6 + math.sin(2.0 * math.pi * f2 * t) * 0.4) * env * 0.55
        out.append(s)
    return out

# 4. Engine Loop (Mono for 3D positioning)
def make_engine_loop():
    # 1.2 second seamless loop at base idle/cruise RPM
    duration = 1.2
    total = int(duration * SAMPLE_RATE)
    out = []
    noise = NoiseGen(999)
    base_f = 46.0 # ~2760 RPM fundamental pulse
    for i in range(total):
        t = i / SAMPLE_RATE
        # Seamless loop phase: 2 * pi * integer cycles
        # 1.2 * 46 = 55.2 -> let's use exactly 55 cycles in 1.2s -> f = 55 / 1.2 = 45.8333 Hz
        f = 55.0 / duration
        phase = 2.0 * math.pi * f * t
        
        # Piston rumble harmonics
        h1 = math.sin(phase) * 0.55
        h2 = math.sin(phase * 2.0) * 0.35
        h3 = math.sin(phase * 3.0) * 0.22
        h4 = math.sin(phase * 4.0) * 0.15
        h6 = math.sin(phase * 6.0) * 0.10
        
        # Exhaust cylinder stroke texture (half-wave rectified thrum)
        stroke = max(0.0, math.sin(phase * 0.5)) * 0.25
        
        # Mechanical combustion flutter
        flutter = noise.next() * 0.08 * (0.6 + 0.4 * math.sin(phase * 2.0))
        
        s = (h1 + h2 + h3 + h4 + h6 + stroke + flutter) * 0.45
        out.append(s)
    return out

# 5. Nitro Boost & Loop
def make_nitro_boost():
    duration = 0.85
    total = int(duration * SAMPLE_RATE)
    out = []
    noise = NoiseGen(777)
    for i in range(total):
        t = i / SAMPLE_RATE
        # Explosion transient in first 0.15s
        env_boom = min(1.0, t / 0.008) * math.exp(-t / 0.12)
        f_boom = 90.0 - 50.0 * (t / 0.2) if t < 0.2 else 40.0
        s_boom = math.sin(2.0 * math.pi * f_boom * t) * env_boom * 0.6
        
        # Rushing rocket hiss/whoosh
        env_whoosh = min(1.0, t / 0.04) * (1.0 - (t / duration) ** 1.5)
        f_cut = 600.0 + 1800.0 * (1.0 - t / duration)
        raw_noise = noise.next()
        # Simple IIR-style high-energy sweep
        s_whoosh = raw_noise * env_whoosh * 0.45
        
        s = s_boom + s_whoosh
        out.append(s * 0.65)
    return out

def make_nitro_loop():
    # 1.0s seamless thrust loop
    duration = 1.0
    total = int(duration * SAMPLE_RATE)
    out = []
    noise = NoiseGen(888)
    for i in range(total):
        t = i / SAMPLE_RATE
        # High-energy jet thrust hiss with smooth cyclic modulation
        mod = 0.85 + 0.15 * math.sin(2.0 * math.pi * 6.0 * t)
        ns = noise.next() * mod * 0.38
        sub = math.sin(2.0 * math.pi * 65.0 * t) * 0.2
        out.append(ns + sub)
    return out

# 6. Finish, Victory, and Defeat
def make_finish_line():
    duration = 0.75
    total = int(duration * SAMPLE_RATE)
    out = []
    noise = NoiseGen(555)
    for i in range(total):
        t = i / SAMPLE_RATE
        whoosh_env = min(1.0, t / 0.08) * math.exp(-t / 0.22)
        whoosh = noise.next() * whoosh_env * 0.35
        chime_env = math.exp(-t / 0.28)
        chime = (math.sin(2.0 * math.pi * 1046.5 * t) + 0.4 * math.sin(2.0 * math.pi * 1567.98 * t)) * chime_env * 0.4
        out.append(whoosh + chime)
    return out

def make_victory():
    duration = 1.6
    total = int(duration * SAMPLE_RATE)
    out = []
    # Fanfare: C5, E5, G5, C6, G5, C6 (triumphant held chord)
    notes = [
        (0.00, 0.14, 523.25),  # C5
        (0.14, 0.28, 659.25),  # E5
        (0.28, 0.42, 783.99),  # G5
        (0.42, 0.70, 1046.50), # C6
        (0.70, 0.90, 783.99),  # G5
        (0.90, 1.60, 1046.50), # C6 chord
        (0.90, 1.60, 1318.51)  # E6 chord
    ]
    for i in range(total):
        t = i / SAMPLE_RATE
        sample = 0.0
        for n_start, n_end, freq in notes:
            if n_start <= t < n_end:
                t_rel = t - n_start
                dur = n_end - n_start
                env = min(1.0, t_rel / 0.01) * math.exp(-t_rel / (dur * 0.75))
                # Trumpet / bright synth tone
                tone = math.sin(2.0 * math.pi * freq * t) + 0.4 * math.sin(4.0 * math.pi * freq * t) + 0.15 * math.sin(6.0 * math.pi * freq * t)
                sample += tone * env * 0.25
        out.append(sample)
    return out

def make_defeat():
    duration = 1.1
    total = int(duration * SAMPLE_RATE)
    out = []
    # Warm, reflective completion chime: G4, E4, D4, C4
    notes = [
        (0.00, 0.22, 392.00), # G4
        (0.22, 0.44, 329.63), # E4
        (0.44, 0.66, 293.66), # D4
        (0.66, 1.10, 261.63)  # C4
    ]
    for i in range(total):
        t = i / SAMPLE_RATE
        sample = 0.0
        for n_start, n_end, freq in notes:
            if n_start <= t < n_end:
                t_rel = t - n_start
                dur = n_end - n_start
                env = min(1.0, t_rel / 0.01) * math.exp(-t_rel / (dur * 0.6))
                tone = math.sin(2.0 * math.pi * freq * t) + 0.2 * math.sin(4.0 * math.pi * freq * t)
                sample += tone * env * 0.35
        out.append(sample)
    return out

def make_achievement_unlock():
    duration = 1.2
    total = int(duration * SAMPLE_RATE)
    out = []
    # Shimmering golden chime: F5, A5, C6, E6
    notes = [
        (0.00, 0.10, 698.46),  # F5
        (0.08, 0.18, 880.00),  # A5
        (0.16, 0.28, 1046.50), # C6
        (0.24, 1.20, 1318.51)  # E6
    ]
    for i in range(total):
        t = i / SAMPLE_RATE
        sample = 0.0
        for n_start, n_end, freq in notes:
            if n_start <= t < n_end:
                t_rel = t - n_start
                env = min(1.0, t_rel / 0.005) * math.exp(-t_rel / 0.25)
                tone = math.sin(2.0 * math.pi * freq * t) + 0.3 * math.sin(4.0 * math.pi * freq * t)
                sample += tone * env * 0.28
        out.append(sample)
    return out

def make_level_up():
    duration = 1.3
    total = int(duration * SAMPLE_RATE)
    out = []
    # Heroic rising triad: D5, F#5, A5, D6
    notes = [
        (0.00, 0.12, 587.33),  # D5
        (0.12, 0.24, 739.99),  # F#5
        (0.24, 0.36, 880.00),  # A5
        (0.36, 1.30, 1174.66)  # D6
    ]
    for i in range(total):
        t = i / SAMPLE_RATE
        sample = 0.0
        for n_start, n_end, freq in notes:
            if n_start <= t < n_end:
                t_rel = t - n_start
                env = min(1.0, t_rel / 0.008) * math.exp(-t_rel / 0.35)
                tone = math.sin(2.0 * math.pi * freq * t) + 0.35 * math.sin(4.0 * math.pi * freq * t) + 0.15 * math.sin(6.0 * math.pi * freq * t)
                sample += tone * env * 0.32
        out.append(sample)
    return out

# 7. Menu Music Loop (Stereo)
def make_menu_theme():
    bpm = 124.0
    beat_dur = 60.0 / bpm
    bars = 4
    total_dur = bars * 4 * beat_dur # ~7.7419s
    total_samples = int(total_dur * SAMPLE_RATE)
    
    # Bass progression in F minor (F -> Ab -> Bb -> C)
    bass_notes = [87.31, 103.83, 116.54, 130.81] # F2, Ab2, Bb2, C3
    
    # Chord pads (Fm, Ab, Bbm, Cm)
    chords = [
        [174.61, 207.65, 261.63], # F3, Ab3, C4
        [207.65, 261.63, 311.13], # Ab3, C4, Eb4
        [233.08, 277.18, 349.23], # Bb3, Db4, F4
        [261.63, 311.13, 392.00]  # C4, Eb4, G4
    ]
    
    noise = NoiseGen(111)
    stereo_out = []
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        beat_pos = t / beat_dur
        bar_idx = int(beat_pos / 4.0) % bars
        in_bar_beat = beat_pos % 4.0
        
        # 1. Kick on each beat
        kick_env = math.exp(-((in_bar_beat % 1.0) * beat_dur) / 0.08)
        kick_f = 130.0 - 90.0 * min(1.0, (in_bar_beat % 1.0) / 0.15)
        kick = math.sin(2.0 * math.pi * kick_f * t) * kick_env * 0.55
        
        # 2. Snare / Clap on beats 2 and 4
        snare_time = min((in_bar_beat - 1.0) % 2.0, (in_bar_beat - 3.0) % 2.0)
        snare_env = math.exp(-(snare_time * beat_dur) / 0.12) if 0.0 <= snare_time < 0.8 else 0.0
        snare = noise.next() * snare_env * 0.35
        
        # 3. Hi-hat on 8th notes (0.0, 0.5, 1.0, 1.5...)
        hh_time = (beat_pos * 2.0) % 1.0
        hh_env = math.exp(-(hh_time * (beat_dur / 2.0)) / 0.025)
        hh = noise.next() * hh_env * 0.18
        
        # 4. Arpeggiated 16th-note synth bassline
        sub_beat_16 = int((beat_pos * 4.0)) % 16
        bass_root = bass_notes[bar_idx]
        # Arp pattern: root, oct, 5th, oct
        arp_mult = [1.0, 2.0, 1.5, 2.0][sub_beat_16 % 4]
        b_freq = bass_root * arp_mult
        b_t = (beat_pos * 4.0) % 1.0
        b_env = math.exp(-(b_t * (beat_dur / 4.0)) / 0.09)
        bass = (math.sin(2.0 * math.pi * b_freq * t) + 0.3 * math.sin(4.0 * math.pi * b_freq * t)) * b_env * 0.35
        
        # 5. Lush Chord Pads (detuned saw/sine stereo)
        pad_l = 0.0
        pad_r = 0.0
        cur_chord = chords[bar_idx]
        for idx, cf in enumerate(cur_chord):
            # Subtle detuning and stereo chorus
            pad_l += (math.sin(2.0 * math.pi * (cf * 1.002) * t) + 0.25 * math.sin(4.0 * math.pi * cf * t)) * 0.08
            pad_r += (math.sin(2.0 * math.pi * (cf * 0.998) * t) + 0.25 * math.sin(4.0 * math.pi * cf * t)) * 0.08
            
        left_ch = kick + snare * 0.8 + hh * 0.6 + bass * 0.9 + pad_l
        right_ch = kick + snare * 0.8 + hh * 0.9 + bass * 0.9 + pad_r
        
        stereo_out.append((left_ch * 0.55, right_ch * 0.55))
        
    return stereo_out

# 8. Race Music Loop (Stereo)
def make_race_theme():
    bpm = 138.0
    beat_dur = 60.0 / bpm
    bars = 4
    total_dur = bars * 4 * beat_dur # ~6.9565s
    total_samples = int(total_dur * SAMPLE_RATE)
    
    # Energetic driving progression in D minor (D -> F -> C -> G)
    bass_notes = [73.42, 87.31, 65.41, 98.00] # D2, F2, C2, G2
    lead_notes = [
        [587.33, 698.46, 880.00, 1174.66], # D5, F5, A5, D6
        [698.46, 880.00, 1046.50, 1396.91], # F5, A5, C6, F6
        [523.25, 659.25, 783.99, 1046.50],  # C5, E5, G5, C6
        [783.99, 987.77, 1174.66, 1567.98]  # G5, B5, D6, G6
    ]
    
    noise = NoiseGen(333)
    stereo_out = []
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        beat_pos = t / beat_dur
        bar_idx = int(beat_pos / 4.0) % bars
        in_bar_beat = beat_pos % 4.0
        
        # 1. Driving four-on-the-floor punchy kick
        kick_env = math.exp(-((in_bar_beat % 1.0) * beat_dur) / 0.07)
        kick_f = 140.0 - 95.0 * min(1.0, (in_bar_beat % 1.0) / 0.12)
        kick = math.sin(2.0 * math.pi * kick_f * t) * kick_env * 0.60
        
        # 2. Snare / Clap on beats 2 and 4
        snare_time = min((in_bar_beat - 1.0) % 2.0, (in_bar_beat - 3.0) % 2.0)
        snare_env = math.exp(-(snare_time * beat_dur) / 0.10) if 0.0 <= snare_time < 0.8 else 0.0
        snare = noise.next() * snare_env * 0.38
        
        # 3. Off-beat 8th note open hi-hat (driving EDM pulse)
        hh_time = (beat_pos - 0.5) % 1.0
        hh_env = math.exp(-(hh_time * beat_dur) / 0.06) if 0.0 <= hh_time < 0.7 else 0.0
        hh = noise.next() * hh_env * 0.22
        
        # 4. Rolling 16th-note driving bass
        sub_16 = int(beat_pos * 4.0) % 16
        b_root = bass_notes[bar_idx]
        octave = 2.0 if (sub_16 % 4 == 2 or sub_16 % 4 == 3) else 1.0
        b_freq = b_root * octave
        b_env = math.exp(-(((beat_pos * 4.0) % 1.0) * (beat_dur / 4.0)) / 0.08)
        bass = (math.sin(2.0 * math.pi * b_freq * t) + 0.35 * math.sin(4.0 * math.pi * b_freq * t)) * b_env * 0.38
        
        # 5. Fast Arpeggiated Racing Lead Synths
        arp_idx = int(beat_pos * 4.0) % 4
        lead_freq = lead_notes[bar_idx][arp_idx]
        lead_env = math.exp(-(((beat_pos * 4.0) % 1.0) * (beat_dur / 4.0)) / 0.09)
        lead_l = (math.sin(2.0 * math.pi * (lead_freq * 1.003) * t) + 0.25 * math.sin(4.0 * math.pi * lead_freq * t)) * lead_env * 0.18
        lead_r = (math.sin(2.0 * math.pi * (lead_freq * 0.997) * t) + 0.25 * math.sin(4.0 * math.pi * lead_freq * t)) * lead_env * 0.18
        
        left_ch = kick + snare * 0.85 + hh * 0.6 + bass * 0.9 + lead_l
        right_ch = kick + snare * 0.85 + hh * 0.9 + bass * 0.9 + lead_r
        
        stereo_out.append((left_ch * 0.55, right_ch * 0.55))
        
    return stereo_out

def main():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    audio_dir = os.path.join(base_dir, "audio")
    sfx_dir = os.path.join(audio_dir, "sfx")
    music_dir = os.path.join(audio_dir, "music")
    
    print("Generating comprehensive game audio assets...")
    
    # UI SFX
    write_wav(os.path.join(sfx_dir, "ui_hover.wav"), make_ui_hover())
    write_wav(os.path.join(sfx_dir, "ui_click.wav"), make_ui_click())
    write_wav(os.path.join(sfx_dir, "ui_track_select.wav"), make_ui_track_select())
    write_wav(os.path.join(sfx_dir, "achievement_unlock.wav"), make_achievement_unlock())
    write_wav(os.path.join(sfx_dir, "level_up.wav"), make_level_up())
    
    # Typing SFX
    write_wav(os.path.join(sfx_dir, "type_click.wav"), make_type_click())
    write_wav(os.path.join(sfx_dir, "type_error.wav"), make_type_error())
    write_wav(os.path.join(sfx_dir, "phrase_complete.wav"), make_phrase_complete())
    
    # Race SFX
    write_wav(os.path.join(sfx_dir, "countdown_beep.wav"), make_countdown_beep())
    write_wav(os.path.join(sfx_dir, "race_start.wav"), make_race_start())
    write_wav(os.path.join(sfx_dir, "engine_loop.wav"), make_engine_loop()) # Mono for 3D positional support
    write_wav(os.path.join(sfx_dir, "nitro_boost.wav"), make_nitro_boost())
    write_wav(os.path.join(sfx_dir, "nitro_loop.wav"), make_nitro_loop())
    write_wav(os.path.join(sfx_dir, "finish_line.wav"), make_finish_line())
    write_wav(os.path.join(sfx_dir, "victory.wav"), make_victory())
    write_wav(os.path.join(sfx_dir, "defeat.wav"), make_defeat())
    
    # Music Loops (Stereo)
    write_wav(os.path.join(music_dir, "menu_theme.wav"), make_menu_theme(), channels=2)
    write_wav(os.path.join(music_dir, "race_theme.wav"), make_race_theme(), channels=2)
    
    print("All audio assets successfully generated!")

if __name__ == "__main__":
    main()
