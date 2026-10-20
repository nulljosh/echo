# Contributing

## Setup

```bash
git clone https://github.com/nulljosh/echo.git && cd echo
scripts/fetch-tiny-model.sh
xcodegen generate && open voxprint.xcodeproj
```

## Test

```bash
TEST_RUNNER_VOXPRINT_QA=1 xcodebuild test -scheme VoxprintTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Keep the diff to what you are fixing, match the style of the file, and say why in the PR.

## Bugs

Open an issue with the smallest steps that show it.

## Security

Found something exploitable? Email trommatic@icloud.com instead of opening an issue. You will hear back within a week. This is a solo project, so there is no bounty. Supported: the version on the App Store and the tip of `main`.
