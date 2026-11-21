# Publishing Survey Contour Generator on Google Play - first release guide

This guide takes the app from the signed `.aab` on your machine to a live Play listing. Companion files:

- [`listing.md`](listing.md) - title, short and full description, release notes, graphics specs
- [`privacy-policy.md`](privacy-policy.md) - policy text (hosted copy: `web/privacy.html`)
- [`assets/`](assets/) - icon, feature graphic, screenshots

Policy details change. Where a number below comes from Google it is linked; confirm it in Play Console before relying on it.

---

## 0. Decide these before the first upload (they are permanent)

| Decision | Current value | Why it matters |
|---|---|---|
| **Application ID** | `com.makeshtech.survey_contour_generator` | Decided. It follows the pattern of your other apps (`com.makeshtech.<name>`). It is the app's identity on Play and **can never be changed after the first upload.** |
| Account type | personal, created before 13 Nov 2023 | Decided. The mandatory 12-tester / 14-day closed test does **not** apply (section 3). |
| Public support email | not decided | Shown on the store page. Use a dedicated address. |
| Upload key | `android/key.properties` + keystore | Back it up (see section 2). |
| License | MIT (`LICENSE`) | Open source, same as your other apps. Mention it in the listing (already in the draft). |

---

## 1. Create the developer account

> **You already have a personal developer account (created before 13 Nov 2023), so skip to section 2.** Check in Play Console that identity verification is complete and that the account email is the one you want on the listing. The steps below are for reference.

1. Go to <https://play.google.com/console/signup> and sign in with the Google account that should own the app. Prefer a dedicated account, not a personal inbox.
2. Choose **Personal** or **Organization**.
   - **Personal**: your legal name and address are verified. Google's closed-testing rule applies (section 3).
   - **Organization**: needs a registered business and a D-U-N-S number. Closed-testing rule does not apply.
3. Pay the one-time registration fee (USD 25).
4. Complete identity verification: government ID, contact phone and email, and (for personal accounts) verification on a physical Android device with the Play Console app. This can take from hours to several days.
5. Accept the Developer Distribution Agreement.

Keep the account email and 2-step verification secured. Losing the account loses the listing.

---

## 2. Signing: what Google does with your key

You already build a signed bundle. In Play Console you will use **Play App Signing**:

- The first time you upload, accept Play App Signing. Google holds the real app-signing key; the key in `android/key.properties` becomes your **upload key**.
- **Back up** the keystore file and `key.properties` outside the repo (password manager or encrypted storage). If the upload key is lost you can request a reset from Play support, but it is slow.
- Never commit them. They are already git-ignored.

---

## 3. Create the app

1. Play Console > **Create app**.
2. App name: `Survey Contour Generator`. Default language: English (United States). **App**. **Free**.
3. Tick the declarations (Developer Program Policies, US export laws) and create.

### Testing requirement

Google requires personal developer accounts **created after 13 November 2023** to run a closed test with at least 12 testers for 14 days before applying for production ([Google help](https://support.google.com/googleplay/android-developer/answer/14151465)). Your personal account was created before that date, so **you can go straight to production**. A short internal or closed test is still recommended (section 9) to confirm the Play-installed build works, but it is not mandatory.

If you ever publish under a newer account, the 12-tester rule applies to that account.

---

## 4. Complete "App content" (Dashboard > Set up your app)

Answers below match what the app actually does. Re-check each question in the Console wording.

| Section | Answer |
|---|---|
| **Privacy policy** | `https://makeshvineeth.github.io/survey-contour-generator/privacy.html` (deploy first, see section 8) |
| **App access** | All functionality is available without login or special access |
| **Ads** | No, the app contains no ads |
| **Content rating** | Run the IARC questionnaire: category *Utility, Productivity, Communication or other*; answer **No** to violence, sexual content, language, controlled substances, gambling, user-generated content and user interaction. Expected result: lowest rating (Everyone / PEGI 3). |
| **Target audience** | **18 and over** (professional tool). Do not select children's age groups; that triggers the Families policy. |
| **Data safety** | *Does your app collect or share any required user data types?* **No.** Data is processed only on the device; no data is collected or shared. Add the privacy policy link. Even apps that collect nothing must submit the form ([Google help](https://support.google.com/googleplay/android-developer/answer/10787469)). |
| **Advertising ID** | App does not use an advertising ID |
| **Government apps** | No |
| **Financial features** | None |
| **Health apps / health connect** | Not a health app |
| **News app** | No |
| **COVID / data deletion** | Not applicable. There are no accounts, so there is no account-deletion URL to provide. |
| **Permissions declarations** | None needed. The release manifest declares no sensitive permissions (verified: no INTERNET, no storage). |

---

## 5. Store listing

Dashboard > **Grow users > Store presence > Main store listing**. Paste the text from [`listing.md`](listing.md) and upload from [`assets/`](assets/):

1. App name, short description, full description.
2. App icon (`icon-512.png`), feature graphic (`feature-graphic-1024x500.png`).
3. Phone screenshots: upload the 6 captioned images in order (map first).
4. Optional: 7-inch and 10-inch tablet screenshots; a promo video.
5. **Store settings**: category (Tools), tags, public email, website.
6. Save, then check **Preview** for each device type.

Do not mention Autodesk products as if endorsed; the description already carries the trademark disclaimer.

---

## 6. Pricing and distribution

1. **Countries / regions**: select where to publish (start with all, or a short list).
2. Confirm the app is free, contains no ads, and accepts the content guidelines and US export laws.
3. Devices: leave defaults. The app supports phones and tablets (min Android 7.0, API 24; target API 36).

---

## 7. Build and upload

Requirements Google checks, all met by the current build:

| Requirement | Status |
|---|---|
| Android App Bundle (`.aab`) | yes |
| Target API level (new apps must target Android 16 / API 36 from 31 Aug 2026, [Google](https://support.google.com/googleplay/android-developer/answer/11926878)) | targets 36 |
| 64-bit native code | arm64-v8a and x86_64 included |
| 16 KB page-size support (native libraries must be 16 KB aligned for Android 15+ targets) | verified: all `.so` LOAD segments aligned to 16 KB or 64 KB |
| Increasing `versionCode` for every upload | `pubspec.yaml`: `13.0.0+1300`; bump the `+` number each release |

Build:

```powershell
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

Files (from `build/app/outputs/`):

| File | Where it goes |
|---|---|
| `bundle/release/app-release.aab` | the release upload |
| `mapping/release/mapping.txt` | release page > App bundle explorer > Downloads > upload deobfuscation file |
| `native-debug-symbols/release/native-debug-symbols.zip` | same place, upload debug symbols |
| `symbols/dart-obfuscation-symbols.zip` | keep privately; needed for `flutter symbolize` on crash stack traces |

---

## 8. Publish the privacy policy first

Play Console rejects the listing without a reachable policy URL.

```bash
tool/deploy_pages.sh
```

This rebuilds the web app (it includes `web/privacy.html`) and publishes it to GitHub Pages. Check that <https://makeshvineeth.github.io/survey-contour-generator/privacy.html> opens.

---

## 9. Release path

Because your account predates the closed-testing rule, the shortest route is:

1. **Internal testing** (recommended, instant): Testing > Internal testing > Create new release, upload the `.aab`, add yourself (and a few others) as testers by email, open the opt-in link on your phone and install from Play. Confirm the app starts, imports the sample data and exports a file. Apps only on the internal track do not need the Data safety form yet.
2. **Production**: Production > **Create new release**, upload the `.aab` (or promote the tested release), add the release notes, Review, then **Start rollout**. Use a staged rollout (for example 20%, then 100%) to limit the impact of a bad build.
3. **Review**: a new app's first review commonly takes several days. Google emails you and posts a Console message if something needs fixing.
4. Optional: run a **closed test** first anyway to collect feedback from surveyors before the public launch; it does not delay anything if you skip it.

---

## 10. Pre-launch checklist

- [ ] Application ID is final, and the `.aab` was built with it
- [ ] Privacy policy URL is live
- [ ] Support email chosen
- [ ] All "App content" sections show green ticks
- [ ] Store listing complete: text, icon, feature graphic, at least 2 phone screenshots (6 supplied)
- [ ] Release signed with the upload key; `mapping.txt` and native symbols uploaded
- [ ] Internal test install checked from the Play link
- [ ] Pre-launch report reviewed (Play runs the app on test devices automatically for closed, open and production tracks; fix crashes)
- [ ] Upload key and keystore backed up

---

## 11. After launch

- **Updates**: bump `version:` in `pubspec.yaml` (for example `13.0.1+1301`), rebuild the `.aab`, upload to the same track, upload the new `mapping.txt`.
- **Monitor** Android vitals (crashes, ANRs), ratings and reviews. Reply to reviews from the Console.
- **Stay compliant**: new target-API deadlines arrive every August (API 37 is next); keep the Data safety form accurate if you ever add a network feature or SDK.
- **Keep the web app and Play app in step**: both come from this repository; release notes live in `CHANGELOG.md`.

---

## 12. Official references

- Closed-testing requirement for new personal accounts: <https://support.google.com/googleplay/android-developer/answer/14151465>
- Target API level requirements: <https://support.google.com/googleplay/android-developer/answer/11926878>
- Data safety form: <https://support.google.com/googleplay/android-developer/answer/10787469>
- Store listing and preview assets: <https://support.google.com/googleplay/android-developer/answer/13393723>, <https://support.google.com/googleplay/android-developer/answer/9866151>
- Prepare your app for review: <https://support.google.com/googleplay/android-developer/answer/9815348>
