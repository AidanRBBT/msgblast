# Developer ID signing setup evidence

The CLI results were captured from the source hashes in source-sha256.json. replay.html presents those exact outputs; it does not execute commands. The unit suite uses simulated Keychain, Apple and R2 calls. The two real local CLI checks reject incomplete Developer ID configuration and refuse non-CI credential installation before contacting a release store or mutating Keychain.

The screenshots and sampled video capture this read-only replay with edited timing. They are not a real certificate import, notarization acceptance, production build, release publication or permission-retention test. Native macOS/CI changes only; mobile screenshots do not apply. No Apple credentials or account pages are included in this private repository evidence.

The authorized real certificate/private-key pairing and Apple notarization authentication were checked separately without logging credentials. Encrypted repository secrets are configured. The dedicated non-publishing verify-signing workflow must pass on the reviewed main revision before Developer ID activation. Real app signing/notarization and TCC retention remain first-release verification requirements.
