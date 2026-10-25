#!/usr/bin/env python3
"""Check the USB descriptors in a built FM-1 app image (the firmware's app/*.bin, not the package).

The macOS 13-15 USB audio bug is fixed by the *interface order*: MIDI must come after the audio
streaming interfaces, and must not be part of the AC header's collection (README section 7). The
firmwares whose upstream test suite has no descriptor test are checked here, by reading the built
image, so the host-compat set is verified on the bytes that get flashed.

  usb_desc.py IMAGE            exit 0 when the host-compat set is present, 1 with a reason otherwise

Checks: the configuration descriptor parses; the audio control interface comes first, then every
audio streaming interface, then the MIDI streaming function; the AC header's collection names the
streaming interfaces only (never MIDI); the device has a serial number string (so a host tells
firmwares sharing VID/PID 1209:0001 apart). The audio function's IAD is reported (it is hygiene,
not the fix) and must cover AC + AS, not MIDI, when present.
"""
import sys


def find_config(b):
    for o in range(len(b) - 9):
        if b[o] != 9 or b[o + 1] != 2:
            continue
        n = b[o + 2] | b[o + 3] << 8
        if not (9 < n <= 512) or b[o + 4] > 16 or b[o + 5] != 1 or b[o + 7] != 0x80:
            continue
        p, ok = o + 9, True
        while p < o + n:
            if b[p] < 2:
                ok = False
                break
            p += b[p]
        if ok and p == o + n:
            return o
    return None


def find_device(b, before):
    found = None
    for o in range(before):
        if b[o] == 18 and b[o + 1] == 1 and b[o + 8] == 9 and b[o + 9] == 0x12:
            found = o
    return found


def main(argv):
    if len(argv) != 2:
        print("usage: usb_desc.py IMAGE", file=sys.stderr)
        return 2
    b = open(argv[1], "rb").read()
    o = find_config(b)
    if o is None:
        print("no configuration descriptor found", file=sys.stderr)
        return 1
    end, p = o + (b[o + 2] | b[o + 3] << 8), o + 9
    ifaces, iads, collections = [], [], []
    while p < end:
        n, t = b[p], b[p + 1]
        if t == 4:
            ifaces.append((b[p + 2], b[p + 5], b[p + 6], b[p + 7]))
        elif t == 0x0B:
            iads.append((b[p + 2], b[p + 3], b[p + 4], b[p + 5], b[p + 6]))
        elif t == 0x24 and b[p + 2] == 1 and n >= 9:   # AC interface header: bInCollection, baInterfaceNr
            collections.append((b[p + 7], list(b[p + 8:p + 8 + b[p + 7]])))
        p += n

    errors = []
    # the AC interface is 0 here; an interface number is repeated for each alternate setting, so
    # collapse to the first occurrence per number and check the classes in interface order
    order = []
    for num, cls, sub, proto in ifaces:
        if not order or order[-1][0] != num:
            order.append((num, cls, sub, proto))
    if not order or order[0][1:] != (1, 1, 0):
        errors.append("the first interface is not the audio control interface: %r" % (order[:1],))
    midi = [i for i in order if i[1] == 1 and i[2] == 3]
    streams = [i for i in order if i[1] == 1 and i[2] == 2]
    if not midi:
        errors.append("no MIDI streaming interface")
    if not streams:
        errors.append("no audio streaming interface")
    if order and midi and streams:
        midi_at = order.index(midi[0])
        if any(order.index(s) > midi_at for s in streams):
            errors.append("MIDI (interface %d) is not behind the audio streams (%s)"
                          % (midi[0][0], ", ".join(str(s[0]) for s in streams)))
    for total, named in collections:
        if midi and midi[0][0] in named:
            errors.append("the AC header's collection names the MIDI interface %d" % midi[0][0])
        want = [s[0] for s in streams]
        if total != len(want) or named != want:
            errors.append("the AC header's collection is %s, expected the streams %s"
                          % (named, want))
    for first, count, cls, sub, proto in iads:
        if cls == 1:
            if first != 0:
                errors.append("the audio IAD starts at interface %d, not the AC interface" % first)
            covered = set(range(first, first + count))
            if midi and midi[0][0] in covered:
                errors.append("the audio IAD covers the MIDI interface %d" % midi[0][0])
            if any(s[0] not in covered for s in streams):
                errors.append("the audio IAD does not cover every stream")

    d = find_device(b, o)
    serial = b[d + 16] if d is not None else 0
    if d is None:
        errors.append("no device descriptor found")
    elif not serial:
        errors.append("iSerialNumber is 0: the device has no serial number string")

    print("config   at 0x%x, %d bytes; interfaces %s" % (
        o, end - o, ", ".join("%d:%d/%d" % (n, c, s) for n, c, s, _ in order)))
    print("AC coll  %s" % (", ".join("total %d, %s" % (t, n) for t, n in collections) or "none"))
    print("IAD      %s" % (", ".join("first %d, %d ifaces, %02x %02x %02x" % i for i in iads) or "none"))
    print("serial   iSerialNumber %d%s" % (serial, "" if d is not None else " (no device descriptor)"))
    if errors:
        for e in errors:
            print("  FAIL  " + e, file=sys.stderr)
        return 1
    print("USB descriptors: host-compatible (MIDI behind the streams, out of the AC collection)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
