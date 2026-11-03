# KNOWME VPN

Flutter starter project for an iOS + Android WireGuard client with a red/black UI.

## Included
- KNOWME VPN home screen
- Connect/disconnect controls wired to `wireguard_flutter_plus`
- Import and basic validation of WireGuard `.conf` files
- Live tunnel stage listener
- No fake server list or fabricated ping value

## Important status
This is a starter source project, not a signed IPA/APK and not a turnkey VPN service.
A `.conf` file must contain valid client credentials and point to a real WireGuard server.
Never share a `.conf` file publicly: it contains a private key.

## Run
1. Install Flutter SDK and Android Studio / Xcode.
2. Run `flutter pub get`.
3. Run on Android: `flutter run`.
4. For iOS, open `ios/Runner.xcworkspace` in Xcode and complete the Packet Tunnel Extension setup below.

## iOS setup required
The WireGuard plugin requires an iOS Packet Tunnel Network Extension and Apple Network Extension entitlement.
1. In Xcode, add a Network Extension target using the Packet Tunnel Provider template.
2. Set its bundle identifier to `com.knowme.vpn.WGExtension` (or change `kExtensionBundleId` in `lib/main.dart` to match).
3. Configure the required Network Extension and App Group capabilities for the app and extension as described by the plugin's current iOS setup guide.
4. Ensure the App Group identifier is the same in both targets.
5. Use a valid Apple signing team/profile that permits the Network Extension capability.
6. Test on a physical iPhone. Simulator testing is not a substitute for a real VPN test.

The bundle identifiers above are placeholders. Confirm availability and entitlement support in your Apple Developer setup.

## Android setup
The plugin documentation lists Android VPN support. Review its current Android setup and minimum SDK requirements, then build and test on a physical Android device. The app must receive the system VPN permission prompt.

## Build
- Android APK: `flutter build apk --release`
- iOS archive: use Xcode on macOS with valid signing and Network Extension provisioning.

A normal Windows/Linux environment cannot produce a properly signed iOS IPA by itself; iOS signing/archive requires macOS with Xcode.

## Security notes
- Do not commit real `.conf` files, private keys, or credentials to GitHub.
- Add local config files to `.gitignore`.
- Use only VPN servers you own or are authorized to use.
- The app does not provide VPN servers; it is a client for your own valid WireGuard profiles.
