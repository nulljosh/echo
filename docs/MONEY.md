# Echo Money

How Echo makes money. The company plan is `REVENUE.md` in the Code root; the ledger is `GTM.md`.

## Price and rail

$0.99 upfront on the App Store (ASC 6782604262), one purchase for iPhone and Mac. Apple keeps 15%, so each sale pays about $0.84. There is no unlock, no paywall and no in-app purchase in the code; the unlock was removed in 1.4.0. The store listing still says Notate until Apple accepts the name Echo.

## What is actually sold

The app. Transcription runs on the device with Whisper, or with Apple's speech engine where the system has it. The Mac meeting capture and the keyboard are part of it. The models are open source, and nothing sold is someone else's content. The risk is the App Store's rules on keyboards and microphones, not copyright.

## Who pays and why

Someone who needs a transcriber they can trust with private audio: lawyers, therapists, journalists, anyone under NDA. They pay once because the audio never leaves the device. A cloud transcriber has to charge every month to pay for the compute. Echo does not.

## Cost to serve

No paid API. Transcription costs nothing to serve because it runs on the phone or the Mac. Accounts are optional and run on jaybulb-api. Reset and confirm mail goes out through authmail, which sends through Resend. Resend bills per email, and its cap is set in authmail, not in this repo. Transcripts never go to the server.

## Where we are

- 2026-10-20: renamed back to Echo. The store still says Notate until Apple accepts the name.
- 2026-11-01: Apple refused both Echo and Calliope as store names. The free names are listed in `docs/roadmap.md`.
- Repo notes: 1.4.0 removed the unlock and the paywall, so the price is the only money.
- Revenue: no verified number (the App Store Connect key cannot read sales yet).

## Role in the company plan

Hero candidate. GTM.md names it as one of the three apps to push. It serves Stage 0 directly: private transcription is a paid category where people already pay a dollar, so the first thousand dollars can come from it. Stage 1 needs it on the store charts.

## Next

Give the App Store Connect key the Sales role, so the first sale is a number and not a guess.

## Million, billion, trillion

**A million.** Echo is the private transcriber that lawyers and doctors recommend to each other, paid once, with no bot joining the call.

**A billion.** Echo is the default voice-to-text on every Jaybulb device, and a meeting becomes notes without a cloud.

**A trillion.** Echo is the on-device speech layer under every app on the platform, and it still costs a dollar.

## Change it

`asc pricing schedule create --app 6782604262 --price 0.99 --base-territory USA --start-date YYYY-MM-DD`. Swap `--price 0.99` for `--free` to revert. No build, no review. Only with Joshua's yes in chat.

Anyone who got Echo while it was free keeps it free.

*ASC 6782604262. Verified 2026-11-02.*
