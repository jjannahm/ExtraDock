# Preflight Checklist

## Status: ⏳ PENDING

## Accounts Required
- [x] Apple Developer Account - Required for code signing and notarization (free for open source, paid for App Store)
- [x] GitHub Account - For repository hosting and CI/CD (GitHub Actions)

## API Keys / Environment Variables
- [x] `APPLE_DEVELOPER_ID` - Apple Developer ID for signing (from Apple Developer portal)
- [ ] `APPLE_TEAM_ID` - Apple Team ID (from Apple Developer portal)
- [ ] `APPLE_CERTIFICATE` - P12 certificate for signing (exported from Keychain)
- [ ] `APPLE_CERTIFICATE_PASSWORD` - Password for the P12 certificate
- [ ] `APPLE_APP_SPECIFIC_PASSWORD` - For notarization (from appleid.apple.com)

## Manual Setup (if any)
- [x] Xcode 26.2+ installed (from Mac App Store)
- [x] Command Line Tools installed (`xcode-select --install`)
- [x] macOS 26.2  or later for testing

## Cost Estimate (monthly)
| Service | Free Tier | Paid |
|---------|-----------|------|
| GitHub Actions | 2000 min/mo | $4/mo (extra minutes) |
| Apple Developer | Free (open source) | $99/yr (App Store distribution) |
| Sparkle Framework | Free (open source) | Free |

## Notes
- This project targets macOS 26.2+ so a Mac running 26.2  or later is required
- For open-source distribution outside App Store, a free Apple Developer account suffices
- Paid Apple Developer account ($99/yr) only needed if distributing via Mac App Store
