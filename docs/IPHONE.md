# Put OVRLD on your iPhone

For trying OVRLD on an iPhone before it is on the App Store. You need a **Mac**,
your **iPhone**, a **cable**, and your normal **Apple ID**. It is free.

The catch: Apple lets an app installed this way run for **7 days**. After that
it will not open until you plug in and run step 7 again (two minutes). Your
workouts are kept.

Not on iPhone yet: home-screen widgets and the rest-timer notification.
Everything else works.

---

## One-time setup (about 1 hour, mostly downloads)

**1. Xcode** - Mac App Store → search "Xcode" → Get. It is big (~10 GB). When
it is installed, open it once, accept the licence, and when it offers iOS
platform support, install it.

**2. Homebrew** (skip if `brew --version` works in Terminal):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**3. Flutter and CocoaPods:**

```sh
brew install --cask flutter
brew install cocoapods
flutter doctor
```

`flutter doctor` should show a green tick next to **Xcode**. Android lines can
be red; they do not matter here.

**4. Get the code:**

```sh
cd ~
git clone https://github.com/Rastovic/OVRLD.git
cd OVRLD
flutter pub get
cd apps/ovrld
flutter build ios --config-only
open ios/Runner.xcworkspace
```

**5. Sign it with your Apple ID** (in the Xcode window that just opened):

1. Left sidebar: click **Runner** (blue icon at the top).
2. Middle: under TARGETS click **Runner**, then the **Signing & Capabilities** tab.
3. **Team** → *Add an Account…* → sign in with your Apple ID → choose
   **"Your Name (Personal Team)"**.
4. **Bundle Identifier**: change `com.rastovic.ovrld` to
   `com.YOURNAME.ovrld` (any lowercase name). This one matters: the original id
   is reserved for the App Store version.
5. No red errors left under Signing = done. Close Xcode.

**6. Prepare the iPhone:**

1. Plug it into the Mac, unlock it, tap **Trust This Computer**.
2. iPhone **Settings → Privacy & Security → Developer Mode → On** → restart →
   confirm **Turn On**. (If Developer Mode is not in the list, run step 7 once;
   it appears after that.)

## Install (and every 7 days)

**7.** iPhone plugged in and unlocked, in Terminal:

```sh
cd ~/OVRLD/apps/ovrld
git pull          # gets the newest version
flutter run --release
```

Pick your iPhone if it asks. The first build takes a few minutes. Wait for
"Installing and launching..." to finish, then you can unplug.

**8. First time only:** the app says "Untrusted Developer". On the iPhone:
**Settings → General → VPN & Device Management → your Apple ID → Trust**.
Open OVRLD again.

---

## If something goes wrong

| You see | Do |
|---|---|
| `No valid code signing certificates` / signing errors | Redo step 5; make sure a Team is chosen and the Bundle Identifier is your own |
| `Failed to register bundle identifier` | That id is taken: change it again, e.g. `com.yourname.ovrld2` |
| `CocoaPods not installed` | `brew install cocoapods`, then step 7 again |
| `pod install` errors | `cd ios && pod repo update && cd ..` then step 7 |
| The iPhone is not in the list | Unlock it, re-plug, accept **Trust**, check Developer Mode is on |
| App will not open after a week | Normal (7-day limit). Plug in, run step 7 |

Found a bug? A screenshot plus what you tapped is perfect.
