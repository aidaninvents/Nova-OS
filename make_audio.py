import math
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = ROOT / "audio"
OUTPUT = OUTPUT_DIR / "startup.wav"

SAMPLE_RATE = 22050
CHANNELS = 1
SAMPLE_WIDTH = 2

NOTES = {
    "C5": 523.25,
    "D5": 587.33,
    "E5": 659.25,
    "F5": 698.46,
    "G5": 783.99,
    "A5": 880.00,
    "B5": 987.77,
    "C6": 1046.50,
}

MELODY = [
    ("C5", 0.25),
    ("E5", 0.25),
    ("G5", 0.25),
    ("C6", 0.50),
]


def make_tone(frequency, duration):
    samples = int(SAMPLE_RATE * duration)
    data = bytearray()

    for i in range(samples):
        t = i / SAMPLE_RATE

        # Smooth fade-in/fade-out to avoid clicks.
        fade = min(
            1.0,
            i / (SAMPLE_RATE * 0.01),
            (samples - i) / (SAMPLE_RATE * 0.02),
        )

        value = math.sin(2.0 * math.pi * frequency * t)
        value *= 0.30 * fade

        sample = int(value * 32767)
        data.extend(sample.to_bytes(2, "little", signed=True))

    return data


def make_audio():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    audio = bytearray()

    for note, duration in MELODY:
        frequency = NOTES[note]
        audio.extend(make_tone(frequency, duration))

    with wave.open(str(OUTPUT), "wb") as wav:
        wav.setnchannels(CHANNELS)
        wav.setsampwidth(SAMPLE_WIDTH)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(audio)

    print(f"Created: {OUTPUT}")
    print(f"Sample rate: {SAMPLE_RATE} Hz")
    print(f"Channels: {CHANNELS}")
    print(f"Duration: {len(audio) / (SAMPLE_RATE * SAMPLE_WIDTH):.2f} seconds")
    print(f"Size: {OUTPUT.stat().st_size} bytes")


if __name__ == "__main__":
    make_audio()