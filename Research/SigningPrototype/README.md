# Signing Prototype

Purpose: validate the minimum arm64 hardened-runtime signing workflow for a private preview.

This harness does not package or distribute an application. It records architecture, entitlements, signature verification, and limitations for ADR-003.

Build with `swiftc main.swift -o SigningPrototype`; sign locally with `codesign --force --sign - --options runtime SigningPrototype`; then inspect using `file`, `codesign -dvv`, and `codesign --verify --strict`.
