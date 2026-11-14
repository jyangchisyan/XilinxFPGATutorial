#!/usr/bin/env python3
"""Read-only diagnostics for local Vivado JTAG access; does not program hardware."""
import os
from pathlib import Path
import socket
import sys


def main():
    failures = []
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.bind(("127.0.0.1", 0))
        print("PASS: local TCP socket creation and binding")
    except OSError as exc:
        failures.append("Local TCP is unavailable; hw_server cannot listen here.")
        print(f"FAIL: local TCP: {exc}")

    usb_root = Path("/dev/bus/usb")
    if usb_root.is_dir():
        print("PASS: /dev/bus/usb is available")
    else:
        failures.append("USB device nodes are not exposed to this process.")
        print("FAIL: /dev/bus/usb is missing")

    found = False
    for device in sorted(Path("/sys/bus/usb/devices").glob("*")):
        try:
            vendor = (device / "idVendor").read_text().strip()
            product_id = (device / "idProduct").read_text().strip()
            manufacturer = (device / "manufacturer").read_text().strip()
            if vendor != "0403" or "digilent" not in manufacturer.lower():
                continue
            found = True
            bus = int((device / "busnum").read_text())
            number = int((device / "devnum").read_text())
            node = usb_root / f"{bus:03d}" / f"{number:03d}"
            print(f"INFO: host detects Digilent USB {vendor}:{product_id} at {device.name}")
            if node.exists() and os.access(node, os.R_OK | os.W_OK):
                print(f"PASS: read/write access to {node}")
            else:
                failures.append(f"Digilent USB node is missing or inaccessible: {node}")
                print(f"FAIL: missing or inaccessible USB node: {node}")
        except (OSError, ValueError):
            continue
    if not found:
        failures.append("No Digilent USB device was found in host sysfs.")
        print("FAIL: no Digilent USB device in host sysfs; check USB PROG cable and power")

    if failures:
        print("\nJTAG preflight failed; no programming was attempted.")
        for reason in failures:
            print(f"- {reason}")
        print("Run from a host terminal with USB access and local TCP permitted.")
        return 1
    print("\nJTAG preflight passed. Use scripts/program.tcl to inspect/program the FPGA.")
    print("USB detection alone does not verify FPGA power, JTAG chain, or FPGA configuration.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
