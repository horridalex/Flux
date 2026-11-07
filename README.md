# Flux

Share your iPhone's internet with your iPad, Mac or travel router, even when your cellular plan blocks or slows down Personal Hotspot.

**Each device needs a WireGuard client.** The free WireGuard app works on an iPad, iPhone or Mac, and most travel routers (GL.iNet, UniFi Travel Router) have one built in. A device without WireGuard can still join the hotspot, but its traffic goes straight out as hotspot traffic and Flux doesn't help it.

<img src="Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="96" alt="Flux icon">

<img src="docs/sharing.png" width="260" alt="Flux sharing with an iPad, with the speed and the list of devices"> <img src="docs/add-device.png" width="260" alt="Flux with the hotspot on and a QR code for the first device">

## Why this works

Carriers can tell when traffic comes from a device that's connected to your hotspot, and some plans block it or slow it to a crawl. Traffic that comes from the phone itself is fine.

Flux is a small app that runs on your iPhone. Your iPad, Mac or travel router still joins the hotspot, but instead of sending its traffic straight out, its WireGuard client hands it to Flux. Flux makes the connections itself, so they leave from the iPhone like its own traffic.

```
iPad, Mac or router  ──hotspot──▶  Flux on iPhone  ──cellular──▶  internet
(WireGuard client)
```

Under the hood Flux runs a WireGuard server on UDP port 51820, on the hotspot address `172.20.10.1`. Each device connects with its WireGuard client, and everything goes through, calls and games included. WireGuard's own code decrypts the traffic and a small TCP/IP stack inside Flux ([gVisor](https://gvisor.dev)) makes each connection again from the iPhone. UDP behaves like a full-cone NAT, so calls and games can connect directly, and `ping` works too: the iPhone sends it again and only a host that really answers replies. No VPN entitlement or network extension is needed on the iPhone.

## Install Flux on your iPhone

You need an iPhone with Personal Hotspot, and either a Mac with Xcode or your own signing certificate. A free Apple ID is enough with a Mac.

### Without a Mac: the IPA from GitHub Actions

1. In this repository (or your fork of it), Actions > **Build IPA** > Run workflow. It builds on a GitHub-hosted Mac in about 15 minutes.
2. Download `Flux-unsigned` from the run's artifacts. It holds `Flux-unsigned.ipa`, built with the bundle ID `com.personal.flux` and not signed.
3. Sign and install it with your own certificate, in a signing app or with a tool like Sideloadly or AltStore. Keep the same bundle ID every time you install a new build: a signing tool that changes it installs a second Flux with new keys, and every device has to be added again.

Flux shows on its main screen when the certificate has three days or less left, whatever certificate signed it.

### With a Mac and Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Go (`brew install xcodegen go`). `xcodegen generate` builds the WireGuard part with Go first, see `scripts/build-wireguard.sh`.
2. Open `project.yml` and set `DEVELOPMENT_TEAM` to your own team ID (it's empty), and `APP_BUNDLE_ID` to something unique like `com.yourname.flux` if `com.personal.flux` is taken. You'll find your team ID in Xcode under Settings > Accounts.
3. Build and install:

   ```sh
   xcodegen generate
   xcodebuild build -project Flux.xcodeproj -scheme Flux \
     -destination "id=<your-iphone-udid>" -derivedDataPath .build-dd -allowProvisioningUpdates
   xcrun devicectl device install app --device <your-iphone-udid> \
     .build-dd/Build/Products/Debug-iphoneos/Flux.app
   ```

   `xcrun devicectl list devices` shows your iPhone's UDID.

   If Flux is already on the iPhone, build it with the same bundle ID, or a second Flux installs next to it with new keys and every device has to be added again. `xcrun devicectl device info apps --device <your-iphone-udid>` shows the installed one, and `APP_BUNDLE_ID=<that id>` at the end of the `xcodebuild` line uses it.
4. The first time, iOS won't open the app until you trust your developer certificate: Settings > General > VPN & Device Management > your Apple ID > Trust.
5. Open Flux. It waits for Personal Hotspot and starts by itself when the hotspot is on. You can leave it in the background.

## Connect a device with WireGuard

This works for an iPad, an iPhone, a Mac or a travel router. Everything goes through, calls and games too, and nothing changes on other Wi-Fi.

Flux's main screen always shows a QR code for the next device, with the steps under it. There is no button to press. Flux has already made a key for that code. The first time a device connects with it, the device shows up in the Devices list by itself, as Device, Device 2 and so on, and the code changes to a new one for the next device. Tap a device to see if it is connected, remove it, or tap its name at the top to rename it.

- **iPad or iPhone:** install the free [WireGuard](https://apps.apple.com/app/id1441195209) app, then + > Create from QR code and scan the code on Flux's screen. Edit the tunnel and turn On-Demand on for Wi-Fi, only for your iPhone's hotspot name, then join the hotspot. The tunnel turns itself on at the hotspot and off everywhere else.
- **Mac:** the same, but use "Share as a file, for a Mac or a router" under the code (AirDrop works) and Import Tunnel(s) from File, since a Mac can't scan the iPhone's screen.
- **Travel router** (a UniFi Travel Router, a GL.iNet): add a WireGuard client in the router's VPN settings from the shared file, connect the router to the iPhone by USB or the hotspot, and turn its VPN on. Some routers send their clients' traffic from the clients' own addresses instead of their tunnel address. Flux notices that by itself and lets the router's clients through, and its traffic covers every device behind it. On other networks, turn the router's VPN off.

Each device has its own key. Removing a device in Flux locks it out without touching the others.

Devices use Cloudflare's DNS (1.1.1.1) unless you choose other servers under Settings > DNS on Flux's main screen: Google, Quad9, AdGuard (which blocks ads), or up to four IPv4 addresses of your own. The choice goes into the QR code, so it's for devices you add from then on. A device already added keeps its DNS: change it in that device's WireGuard tunnel, or remove the device and add it again.

## Start it from Shortcuts

Once no device has been on the hotspot for 10 minutes, iOS suspends Flux, and it has to be opened again before the hotspot comes back. Shortcuts can do that for you. Flux adds two actions to the Shortcuts app, with nothing to set up:

- **Start Flux** wakes Flux in the background, the same as opening it, but it stays off the screen. It shares as soon as a device joins Personal Hotspot in the next 10 minutes. (iOS only makes the hotspot's network while a device is on it, so that's when Flux can see it.)
- **Is Flux Sharing?** says whether Flux is sharing and how many devices are connected. It gives true or false, for an If.

You can also say "Start Flux" to Siri, find it in Spotlight, or put it on the Action button.

iOS has no automation for "Personal Hotspot turned on", so let one shortcut turn on both:

1. In Shortcuts, make a new shortcut named **Hotspot** with two actions: **Set Personal Hotspot** set to On, then **Start Flux**.
2. Run it instead of turning on the hotspot in Settings: from the Action button, a widget, or Siri ("Hotspot").
3. To have it run by itself, add an automation in Shortcuts > Automation that runs Hotspot and is set to Run Immediately. For example, when your car's Bluetooth connects, when you arrive somewhere you share from, or at a time of day.

## Good to know

- **It stops opening when its certificate expires**: after 7 days with a free Apple ID, or when your own certificate does. Flux says on its main screen when it has three days or less left. Build and install it again before then, with the same bundle ID. Your devices and settings stay.
- **Keep it running.** Flux plays silent audio so iOS doesn't suspend it in the background. It mixes with other audio, so your music keeps playing, and it picks up again after a call or Siri. With no device on the hotspot for 10 minutes it stops, to save battery, and iOS suspends Flux. Open it again, or run Start Flux, before you turn the hotspot back on, and after a restart.
- **It only listens on the hotspot**, never on other Wi-Fi networks. WireGuard only lets in devices you added.
- **Devices reach what the iPhone reaches**, private networks included. With a VPN on the iPhone, your devices use it too, so its networks are open to them and to everyone behind a travel router you added.
- **The main screen** shows whether Flux is sharing, the QR code for the next device, your devices with Connected or Not connected, the current download and upload speed, and how much was used today. A device's own screen shows what it used today, and a travel router's includes every device behind it. Today's figures start again at midnight. To stop sharing, turn off Personal Hotspot.
- **In English and Korean**, following the iPhone's language.
- **The traffic leaves as your iPhone's.** If your iPhone runs a VPN, shared traffic goes through that VPN too.
- **Your carrier can still notice.** Flux hides where the traffic comes from, not what it is. A Mac's software updates or an iPad's apps still look like a Mac or an iPad to a carrier that looks closely. Many carrier contracts don't allow tethering workarounds, and a carrier can slow down or close a line that breaks them. Check yours. Using Flux is your call and your risk.
- **Not for the App Store.** Apple doesn't allow the silent-audio trick, so you build and install Flux yourself.

## For developers

```
Sources/WireGuardServer.swift  runs the WireGuard server; WireGuardSetup.swift has the keys and configs
WireGuard/                   the WireGuard server in Go: wireguard-go plus a gVisor TCP/IP stack
scripts/build-wireguard.sh   builds WireGuard/ into FluxWG.xcframework (xcodegen runs it)
Sources/Model.swift          finds the hotspot, starts the server, samples traffic, feeds the screens
Sources/MainView.swift       the main screen; DevicesView.swift has the QR code and the device screen
Sources/KeepAlive.swift      silent audio to stay alive in the background
Sources/Shortcuts.swift      the Start Flux and Is Flux Sharing? actions for Shortcuts and Siri
Sources/Usage.swift          today's usage, in all and by device
Sources/ko.lproj/            the Korean text; the English is in the code
Sources/DemoMode.swift       fake app states for the UI tests (Debug builds only)
Tests/                       unit tests, run on the Mac
UITests/                     UI tests for every screen, run on the iOS Simulator
scripts/make-icon.swift      draws the app icon
```

The file map at the top of Model.swift lists every source file.

CI runs every test, the fuzzing and an app build on a GitHub-hosted Mac on each push (`.github/workflows/ci.yml`). The UI tests and the IPA build run on demand from the Actions tab.

Run the unit tests with `swift test` (after `scripts/build-wireguard.sh` or `xcodegen generate`, since they link the WireGuard server), and the WireGuard server's own with `go -C WireGuard test ./...`. They start the real server on your Mac and talk to it over loopback, so you don't need a device. [TESTING.md](TESTING.md) covers the simulator UI tests and the checks by hand.

## License

MIT, see [LICENSE](LICENSE). Flux started as Tether by Viktor Svirsky, also MIT, whose copyright notice stays in LICENSE.

The WireGuard server is built from [wireguard-go](https://git.zx2c4.com/wireguard-go) (MIT), [gVisor](https://gvisor.dev) (Apache 2.0) and Go's `golang.org/x` packages (BSD). `WireGuard/go.mod` pins their versions, and Go downloads each one with its license. A built Flux app contains their code, so if you give a build to someone, include their licenses with it.
