from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "fonts" / "BOOTSPIN.FNT"

FRAME_COUNT = 122
FRAME_SIZE = 300
ROW_BYTES = 5
HEIGHT = 60


def read_frames():
    data = FONT.read_bytes()

    # Skip the 10-byte NFNT header.
    data = data[10:]

    frames = []

    for frame in range(FRAME_COUNT):
        start = frame * FRAME_SIZE
        end = start + FRAME_SIZE
        frames.append(data[start:end])

    return frames


def pixel_count(frame):
    return sum(byte.bit_count() for byte in frame)


def bounding_box(frame):
    min_x = ROW_BYTES * 8
    min_y = HEIGHT
    max_x = -1
    max_y = -1

    for y in range(HEIGHT):
        for byte_index in range(ROW_BYTES):
            value = frame[y * ROW_BYTES + byte_index]

            for bit in range(8):
                if value & (0x80 >> bit):
                    x = byte_index * 8 + bit

                    min_x = min(min_x, x)
                    min_y = min(min_y, y)
                    max_x = max(max_x, x)
                    max_y = max(max_y, y)

    if max_x == -1:
        return None

    return min_x, min_y, max_x, max_y


def difference(a, b):
    return sum((x ^ y).bit_count() for x, y in zip(a, b))


frames = read_frames()

print(f"File: {FONT}")
print(f"Frames: {len(frames)}")
print()

print("Frame statistics:")
print("-----------------")

stats = []

for i, frame in enumerate(frames):
    count = pixel_count(frame)
    box = bounding_box(frame)

    stats.append((i, count, box))

    print(
        f"Frame {i:3d}: "
        f"pixels={count:4d}  "
        f"box={box}"
    )

print()
print("Largest differences from neighboring frames:")
print("-----------------------------------------------")

differences = []

for i in range(1, FRAME_COUNT):
    diff = difference(frames[i - 1], frames[i])
    differences.append((diff, i))

for diff, i in sorted(differences, reverse=True)[:10]:
    print(
        f"Frame {i:3d}: "
        f"{diff:4d} pixels different from frame {i - 1}"
    )

print()
print("Most unusual pixel counts:")
print("---------------------------")

average = sum(count for _, count, _ in stats) / FRAME_COUNT

for i, count, box in sorted(
    stats,
    key=lambda item: abs(item[1] - average),
    reverse=True
)[:10]:
    print(
        f"Frame {i:3d}: "
        f"pixels={count:4d} "
        f"(average={average:.1f})"
    )
