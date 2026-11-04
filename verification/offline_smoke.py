"""Generate a tiny RV32I image; validate vectors, not RTL."""
from pathlib import Path
import json


def addi(rd, rs1, imm):
    if not (0 <= rd < 32 and 0 <= rs1 < 32 and -2048 <= imm <= 2047):
        raise ValueError("invalid ADDI operands")
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def main():
    words = [addi(1, 0, 5), addi(2, 0, 7), 0x002081B3, 0x00100073]
    # Fixed encodings provide an independent sanity check of the generator.
    assert words == [0x00500093, 0x00700113, 0x002081B3, 0x00100073]
    assert addi(0, 0, -1) == 0xfff00013
    root = Path(__file__).resolve().parents[1]
    firmware = root / "firmware"
    firmware.mkdir(exist_ok=True)
    (firmware / "smoke.hex").write_text(
        "".join(f"{word:08x}\n" for word in words), encoding="ascii"
    )
    expected = {"halt_reason": "ebreak", "halt_pc": 12,
                "registers": {"x0": 0, "x1": 5, "x2": 7, "x3": 12}}
    (firmware / "smoke.expected.json").write_text(
        json.dumps(expected, indent=2) + "\n", encoding="utf-8"
    )
    print("PASS: smoke vector generation; RTL and hardware are not tested.")


if __name__ == "__main__":
    main()
