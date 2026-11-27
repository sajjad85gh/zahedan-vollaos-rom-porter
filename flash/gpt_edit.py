#!/usr/bin/env python3
"""GPT helper for prepare_gpt.sh.

Works on raw dumps of the first and the last 1 MiB of the disk. No partitioning tool is
needed on the phone, and the vendor's GPT layout is preserved: only the entry array, the
CRC fields of both headers and (in the entry array) the end of `userdata` plus the two
Linux entries are changed.

Sub-commands:
  limits  print the smallest and largest total size (GiB) that can be given to Linux
  plan    parse the dumps, compute the new layout, print it, optionally write patch files
  remove  remove linux_system + linux_data and expand userdata back without a backup
  verify  check dumps against a plan (state "new" or "orig")

Exit codes:
  0  = ok
  10 = linux_system/linux_data already exist (plan/limits)
  11 = linux_system/linux_data do not exist (remove)
  1  = error
"""
import argparse
import json
import struct
import sys
import uuid
import zlib
from pathlib import Path

HDR_FMT = "<8sIIIIQQQQ16sQIII"
HDR_LEN = struct.calcsize(HDR_FMT)  # 92
SIG = b"EFI PART"
ZERO16 = bytes(16)
ALIGN = 2048
GIB = 1 << 30
OFF_HDR_CRC = 16
OFF_ENT_CRC = 88


class GptError(Exception):
    pass


class Dump:
    def __init__(self, head, tail, ssz, total):
        self.head, self.tail, self.ssz, self.total = head, tail, ssz, total
        self.tail_lba = total - len(tail) // ssz

    def read(self, lba, count=1):
        off, n = lba * self.ssz, count * self.ssz
        if off + n <= len(self.head):
            return self.head[off:off + n]
        if lba >= self.tail_lba:
            o = (lba - self.tail_lba) * self.ssz
            if o + n <= len(self.tail):
                return self.tail[o:o + n]
        raise GptError(f"LBA {lba} (+{count}) is outside the dumped areas")


def crc(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def parse_header(raw):
    f = struct.unpack_from(HDR_FMT, raw)
    sig, rev, hsize, hcrc, _res, my, alt, first, last, guid, elba, num, esize, ecrc = f
    if sig != SIG:
        raise GptError("GPT signature not found")
    if not HDR_LEN <= hsize <= len(raw):
        raise GptError(f"bad header size {hsize}")
    tmp = bytearray(raw[:hsize])
    tmp[OFF_HDR_CRC:OFF_HDR_CRC + 4] = bytes(4)
    if crc(bytes(tmp)) != hcrc:
        raise GptError("header CRC mismatch")
    return dict(raw=bytes(raw), hsize=hsize, my=my, alt=alt, first=first, last=last,
                guid=guid, elba=elba, num=num, esize=esize, ecrc=ecrc)


def load_copy(dump, lba):
    h = parse_header(dump.read(lba))
    sectors = -(-h["num"] * h["esize"] // dump.ssz)
    region = dump.read(h["elba"], sectors)
    entries = region[:h["num"] * h["esize"]]
    if crc(entries) != h["ecrc"]:
        raise GptError(f"entry array CRC mismatch (header at LBA {lba})")
    h.update(sectors=sectors, region=region, entries=entries)
    return h


def load(dump):
    p = load_copy(dump, 1)
    if p["my"] != 1:
        raise GptError("primary header does not point at LBA 1")
    if p["alt"] != dump.total - 1:
        raise GptError("backup header is not at the last LBA of the disk")
    b = load_copy(dump, p["alt"])
    if b["my"] != p["alt"] or b["alt"] != 1:
        raise GptError("backup header does not match the primary header")
    for k in ("first", "last", "guid", "num", "esize"):
        if p[k] != b[k]:
            raise GptError(f"primary and backup headers differ in '{k}'")
    if p["entries"] != b["entries"]:
        raise GptError("primary and backup entry arrays differ")
    return p, b


def decode(entries, num, esize):
    out = []
    for i in range(num):
        e = entries[i * esize:(i + 1) * esize]
        if e[:16] == ZERO16:
            continue
        start, end, attr = struct.unpack_from("<QQQ", e, 32)
        name = e[56:esize].decode("utf-16-le", "replace").split("\0", 1)[0]
        out.append(dict(index=i, number=i + 1, type=e[:16], guid=e[16:32],
                        start=start, end=end, attr=attr, name=name))
    return out


def make_entry(esize, ptype, start, end, name):
    e = bytearray(esize)
    e[0:16] = ptype
    e[16:32] = uuid.uuid4().bytes_le
    struct.pack_into("<QQQ", e, 32, start, end, 0)
    n = name.encode("utf-16-le")
    if len(n) > esize - 56:
        raise GptError("partition name too long")
    e[56:56 + len(n)] = n
    return bytes(e)


def rebuild_header(raw, hsize, new_entries_crc):
    b = bytearray(raw)
    struct.pack_into("<I", b, OFF_ENT_CRC, new_entries_crc)
    b[OFF_HDR_CRC:OFF_HDR_CRC + 4] = bytes(4)
    struct.pack_into("<I", b, OFF_HDR_CRC, crc(bytes(b[:hsize])))
    return bytes(b)


def write_plan(out_path, d, p, b, new_entries, new_crc):
    out = Path(out_path)
    new_dir, undo_dir = out / "new", out / "undo"
    new_dir.mkdir(parents=True, exist_ok=True)
    undo_dir.mkdir(parents=True, exist_ok=True)
    plan = [("backup_entries", b["elba"], b["region"], new_entries),
            ("backup_header", b["my"], b["raw"], None),
            ("primary_entries", p["elba"], p["region"], new_entries),
            ("primary_header", p["my"], p["raw"], None)]
    mn = []
    for k, (label, lba, orig, ents) in enumerate(plan, 1):
        if ents is not None:
            new = ents + orig[len(ents):]
        else:
            new = rebuild_header(orig, p["hsize"], new_crc)
        fn = f"{k:02d}_{label}.bin"
        (new_dir / fn).write_bytes(new)
        (undo_dir / fn).write_bytes(orig)
        mn.append(f"{lba} {fn}")
    (new_dir / "manifest.txt").write_text("\n".join(mn) + "\n")
    (undo_dir / "manifest.txt").write_text("\n".join(mn) + "\n")
    with open(out / "plan.json", "w") as f:
        json.dump(dict(ssz=d.ssz, total=d.total, first=p["first"], last=p["last"], guid=p["guid"].hex(),
                       num=p["num"], esize=p["esize"], p_elba=p["elba"], b_elba=b["elba"], alt=p["alt"],
                       orig_entries=p["entries"].hex(), new_entries=new_entries.hex()), f)


def align_up(v):
    return -(-v // ALIGN) * ALIGN


def align_down(v):
    return v // ALIGN * ALIGN


def gib(sectors, ssz):
    return f"{sectors * ssz / GIB:.1f} GiB"


def read_dump(a):
    return Dump(Path(a.head).read_bytes(), Path(a.tail).read_bytes(), a.sector_size, a.total_sectors)


def context(a):
    d = read_dump(a)
    p, b = load(d)
    parts = decode(p["entries"], p["num"], p["esize"])
    ud = [x for x in parts if x["name"] == "userdata"]
    if len(ud) != 1:
        raise GptError("expected exactly one partition named userdata")
    ud = ud[0]
    after = sorted((x for x in parts if x["start"] > ud["end"]), key=lambda x: x["start"])
    tail_end = after[0]["start"] - 1 if after else p["last"]
    if tail_end < ud["end"]:
        raise GptError("partitions overlap userdata")
    return d, p, b, parts, ud, after, tail_end


def geometry(a, ssz, ud, tail_end, total_gib):
    """Layout for giving `total_gib` GiB (linux_system + linux_data) to Linux."""
    sys_sect = align_up(-(-a.system_bytes // ssz))
    tail_sect = align_down(total_gib * GIB // ssz)
    data_target = tail_sect - sys_sect
    if data_target <= 0:
        raise GptError("the requested size is smaller than linux_system")
    data_start = align_down(tail_end + 1 - data_target)
    data_end = tail_end
    sys_start, sys_end = data_start - sys_sect, data_start - 1
    ud_new_end = sys_start - 1
    if (data_end - data_start + 1) * ssz < a.min_data_gib * GIB:
        raise GptError(f"linux_data would be smaller than {a.min_data_gib} GiB; give Linux more space")
    if ud_new_end <= ud["start"] or (ud_new_end - ud["start"] + 1) * ssz < a.min_userdata_gib * GIB:
        raise GptError(f"Android userdata would be smaller than {a.min_userdata_gib} GiB; give Linux less space")
    return dict(sys_sect=sys_sect, sys_start=sys_start, sys_end=sys_end,
                data_start=data_start, data_end=data_end, ud_new_end=ud_new_end)


def cmd_limits(a):
    d, p, b, parts, ud, after, tail_end = context(a)
    if {x["name"] for x in parts} & {"linux_system", "linux_data"}:
        return 10
    ok = []
    for n in range(1, (tail_end - ud["start"] + 1) * d.ssz // GIB + 1):
        try:
            geometry(a, d.ssz, ud, tail_end, n)
            ok.append(n)
        except GptError:
            pass
    if not ok:
        raise GptError("not enough free space in userdata for a Linux installation")
    print(min(ok), max(ok))
    return 0


def cmd_plan(a):
    d, p, b, parts, ud, after, tail_end = context(a)
    ssz, num, esize = d.ssz, p["num"], p["esize"]
    if a.expect_userdata_number and ud["number"] != a.expect_userdata_number:
        raise GptError(f"by-name says userdata is #{a.expect_userdata_number}, the GPT says #{ud['number']}")

    print(f"Disk: {gib(d.total, ssz)}, sector size {ssz}, {len(parts)} partitions, "
          f"usable LBA {p['first']}..{p['last']}")
    print(f"Primary: header LBA 1, entries LBA {p['elba']}; backup: header LBA {b['my']}, entries LBA {b['elba']}")
    if {x["name"] for x in parts} & {"linux_system", "linux_data"}:
        print("linux_system / linux_data already exist.")
        return 10

    g = geometry(a, ssz, ud, tail_end, a.linux_gib)
    sys_sect, sys_start, sys_end = g["sys_sect"], g["sys_start"], g["sys_end"]
    data_start, data_end, ud_new_end = g["data_start"], g["data_end"], g["ud_new_end"]

    max_idx = max(x["index"] for x in parts)
    if max_idx + 2 >= num:
        raise GptError("not enough free entries in the partition array")
    i_sys, i_data = max_idx + 1, max_idx + 2

    ent = bytearray(p["entries"])
    struct.pack_into("<Q", ent, ud["index"] * esize + 40, ud_new_end)
    ent[i_sys * esize:(i_sys + 1) * esize] = make_entry(esize, ud["type"], sys_start, sys_end, "linux_system")
    ent[i_data * esize:(i_data + 1) * esize] = make_entry(esize, ud["type"], data_start, data_end, "linux_data")
    new_entries = bytes(ent)
    new_crc = crc(new_entries)

    print()
    print(f"{'PARTITION':<14}{'NUM':>4}{'START':>13}{'END':>13}{'SIZE':>11}")
    row = lambda n, num_, s, e, tag: print(f"{n:<14}{num_:>4}{s:>13}{e:>13}{gib(e - s + 1, ssz):>11}   ({tag})")
    row("userdata", ud["number"], ud["start"], ud["end"], "before")
    row("userdata", ud["number"], ud["start"], ud_new_end, "after")
    row("linux_system", i_sys + 1, sys_start, sys_end, "new")
    row("linux_data", i_data + 1, data_start, data_end, "new")
    for x in after:
        print(f"kept in place: {x['name']} (#{x['number']}, LBA {x['start']}..{x['end']})")
    print()

    if a.out:
        write_plan(a.out, d, p, b, new_entries, new_crc)
    return 0


def cmd_remove(a):
    d = read_dump(a)
    p, b = load(d)
    parts = decode(p["entries"], p["num"], p["esize"])
    ssz, esize = d.ssz, p["esize"]

    ud_list = [x for x in parts if x["name"] == "userdata"]
    if len(ud_list) != 1:
        raise GptError("expected exactly one partition named userdata")
    ud = ud_list[0]
    if a.expect_userdata_number and ud["number"] != a.expect_userdata_number:
        raise GptError(f"by-name says userdata is #{a.expect_userdata_number}, the GPT says #{ud['number']}")

    lsys_list = [x for x in parts if x["name"] == "linux_system"]
    ldata_list = [x for x in parts if x["name"] == "linux_data"]
    if not lsys_list and not ldata_list:
        print("linux_system / linux_data do not exist. Partition table is already clean.")
        return 11
    if len(lsys_list) != 1 or len(ldata_list) != 1:
        raise GptError("expected both linux_system and linux_data (1 each) to safely remove")
    lsys, ldata = lsys_list[0], ldata_list[0]

    if lsys["start"] != ud["end"] + 1 or ldata["start"] != lsys["end"] + 1:
        raise GptError(
            f"partitions are not contiguous after userdata "
            f"(userdata ends {ud['end']}, linux_system {lsys['start']}..{lsys['end']}, "
            f"linux_data {ldata['start']}..{ldata['end']}); refusing automatic removal"
        )

    for x in parts:
        if x["name"] in ("userdata", "linux_system", "linux_data"):
            continue
        if not (x["end"] < ud["start"] or x["start"] > ldata["end"]):
            raise GptError(f"partition '{x['name']}' overlaps the reclaimed range")

    ud_new_end = ldata["end"]
    ent = bytearray(p["entries"])
    struct.pack_into("<Q", ent, ud["index"] * esize + 40, ud_new_end)
    ent[lsys["index"] * esize:(lsys["index"] + 1) * esize] = bytes(esize)
    ent[ldata["index"] * esize:(ldata["index"] + 1) * esize] = bytes(esize)
    new_entries = bytes(ent)
    new_crc = crc(new_entries)

    print(f"Disk: {gib(d.total, ssz)}, sector size {ssz}, {len(parts)} partitions, "
          f"usable LBA {p['first']}..{p['last']}")
    print()
    print(f"{'PARTITION':<14}{'NUM':>4}{'START':>13}{'END':>13}{'SIZE':>11}")
    row = lambda n, num_, s, e, tag: print(f"{n:<14}{num_:>4}{s:>13}{e:>13}{gib(e - s + 1, ssz):>11}   ({tag})")
    row("userdata", ud["number"], ud["start"], ud["end"], "before")
    row("linux_system", lsys["number"], lsys["start"], lsys["end"], "remove")
    row("linux_data", ldata["number"], ldata["start"], ldata["end"], "remove")
    row("userdata", ud["number"], ud["start"], ud_new_end, "after")
    print()

    if a.out:
        write_plan(a.out, d, p, b, new_entries, new_crc)
    return 0


def cmd_verify(a):
    d = read_dump(a)
    p, b = load(d)
    with open(a.plan) as f:
        pl = json.load(f)
    exp = bytes.fromhex(pl["new_entries" if a.state == "new" else "orig_entries"])
    same = (p["first"], p["last"], p["guid"].hex(), p["num"], p["esize"], p["elba"], b["elba"], p["alt"]) == \
           (pl["first"], pl["last"], pl["guid"], pl["num"], pl["esize"], pl["p_elba"], pl["b_elba"], pl["alt"])
    if not same:
        raise GptError("header fields differ from the plan")
    if p["entries"] != exp:
        raise GptError(f"entry array does not match the expected '{a.state}' state")
    print(f"GPT verified ({a.state} state).")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name in ("plan", "limits", "remove", "verify"):
        s = sp.add_parser(name)
        s.add_argument("--head", required=True)
        s.add_argument("--tail", required=True)
        s.add_argument("--sector-size", type=int, required=True)
        s.add_argument("--total-sectors", type=int, required=True)
        if name in ("plan", "limits"):
            s.add_argument("--system-bytes", type=int, default=10368709120)
            s.add_argument("--min-data-gib", type=int, default=30)
            s.add_argument("--min-userdata-gib", type=int, default=20)
        if name == "plan":
            s.add_argument("--linux-gib", type=int, required=True)
            s.add_argument("--expect-userdata-number", type=int, default=0)
            s.add_argument("--out")
        elif name == "remove":
            s.add_argument("--expect-userdata-number", type=int, default=0)
            s.add_argument("--out")
        elif name == "verify":
            s.add_argument("--plan", required=True)
            s.add_argument("--state", choices=("new", "orig"), required=True)
    a = ap.parse_args()
    try:
        return {"plan": cmd_plan, "limits": cmd_limits, "remove": cmd_remove, "verify": cmd_verify}[a.cmd](a)
    except GptError as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
