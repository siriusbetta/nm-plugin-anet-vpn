#!/usr/bin/env python3
"""Minimal NetworkManager VPN auth-dialog for the HelloWorld plugin."""

import sys


def main() -> int:
    for line in sys.stdin:
        if line.strip() == "DONE":
            break
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
