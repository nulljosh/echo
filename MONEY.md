# Echo Money

How Echo makes money. The fleet-wide ledger is `GTM.md` in the Code root.

## Price

$1, once. The App Store tier is $0.99. Everything unlocked, models included. No in-app purchases, no subscription, no trial counter, no tips. The fleet rule is free or a dollar, so the old plan to raise the price toward $9.99 is dead.

## Rail

The App Store price. Nothing in the code. The old `com.nulljosh.echo.unlock` unlock and its paywall were removed in 1.4.0. Apple keeps 15 percent under the Small Business Program, so a sale nets about 84 cents.

## Why it works

Every word is transcribed on the device, so a user costs nothing to serve. Otter pays for cloud compute on every minute and has to rent the product back by the month. Echo can sit at $1 forever and still be profitable. That gap is the moat. Aiko, the closest on-device rival, charges $19.99.

## Where Otter's money comes from

Otter is around 100 million a year, and almost none of it is people transcribing a voice memo. It is teams paying monthly for the meeting bot: it joins the call, takes notes, writes a summary, lists action items, and lets the whole company search every meeting. Individuals are the funnel. Teams are the revenue.

## How Echo takes the market

At a dollar, the revenue is volume. A million sales is about 840 thousand dollars, so the job is to be the default private transcriber and reach that many people. In order:

1. **Win the privacy crowd Otter cannot serve.** Lawyers, therapists, doctors, journalists, anyone under NDA. Their meetings cannot go to a cloud, and a bot joining the call is itself a problem. "No bot, no cloud, no account" is the whole pitch.
2. **Meetings on the Mac, with no bot.** Capture the mic and the system audio on the device (ScreenCaptureKit) and transcribe locally. This is the one feature that makes Echo a replacement for Otter instead of a cheaper Whisper.
3. **Summary and action items on the device.** Apple's on-device model already runs the cleanup. Point it at the whole transcript and the Otter summary comes for free. Add speaker labels and search across every saved transcript.
4. **Be one tap away everywhere.** Share extension, Action button, Shortcuts, Siri, the Watch recorder that already exists, voice memos import. The easiest app to reach wins the default slot.
5. **Rank for the words people type.** App Store keywords: transcribe, voice to text, offline, private, meeting notes. Screenshots that show airplane mode.
6. **Let the web demo sell it.** The landing runs the app live, no sign-up. Every visitor can try before they pay a dollar.

## The one decision that is Joshua's

A dollar app tops out at volume. The only place real money sits is teams, and teams pay monthly. Staying inside the dollar rule means no team plan. Breaking the rule once means a single one-time Mac "meetings" unlock at about $20 for people expensing it, still no subscription. Not built, not priced. Ask before touching it.

## Change it

`asc pricing schedule` for the app price.

Anyone who got Echo while it was free keeps it.

*ASC 6782604262. Set 2026-09-21, restated 2026-10-18.*
