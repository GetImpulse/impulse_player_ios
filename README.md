# Impulse Player

The Impulse Player makes using a video player in iOS easy. Under the hood, the Impulse Player uses [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer/) for video playback.

Additionally the Impulse Player contains features such as Fullscreen handling and Picture-in-Picture mode out of the box.

Features:

- Single view to show and handle the video player.
- Video quality selection.
- Playback speed selection.
- Fullscreen handling.
- Picture-in-Picture handling.
- Support for casting.

## Installing

### Swift Package Manager

The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding the Impulse Player as a dependency is as easy as adding it to the dependencies value of your Package.swift.

```
dependencies: [
    .package(url: "git@github.com:getimpulse/impulse_player_ios.git", .upToNextMajor(from: "0.2.x"))
]
```

The modules that are available:

- `ImpulsePlayer` **Required**: 
  The core of Impulse Player and is always needed.

### Upgrading

Checkout [CHANGELOG.md](CHANGELOG.md) for the latest changes and upgrade notes.

## Usage

Follow the next steps to get a minimal setup of the library.

### Step 1: Add the `ImpulsePlayerView` to a *ViewController*

Open the *ViewController* and add the following import:

```swift
import ImpulsePlayer
```

Create an instance of the Impulse Player View (for example) in the `viewDidLoad`.

```swift
private lazy var impulsePlayer: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()

func setupImpulsePlayerView() {

    impulsePlayer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(impulsePlayer)
        
    NSLayoutConstraint.activate([
        impulsePlayer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        impulsePlayer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        impulsePlayer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
        impulsePlayer.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0)
    ])
}
```

### Commands

The main commands to use the player:

```swift
impulsePlayer.load(
    title: video.title,
    subtitle: video.subtitle,
    url: video.url
)
impulsePlayer.play()
impulsePlayer.pause()
impulsePlayer.seek(to: 0)
```

### Getters

The values exposed by the player are KVO, which allows to observe the specific value if needed. 

```swift
impulsePlayer.isPlaying // Bool, default `false`
impulsePlayer.state // PlayerState, default `.loading`
impulsePlayer.progress // TimeInterval, default `0.0`
impulsePlayer.duration // TimeInterval, default `0.0`
impulsePlayer.error // Error?, default `nil`
```

### Delegate

Listening to events from the player.

```swift
impulsePlayer.delegate = self

extension ViewController: PlayerDelegate {
    func onReady(_ impulsePlayerView: ImpulsePlayerView) {
        print("onReady")
    }
    
    func onPlay(_ impulsePlayerView: ImpulsePlayerView) {
        print("onPlay")
    }
    
    func onPause(_ impulsePlayerView: ImpulsePlayerView) {
        print("onPause")
    }
    
    func onFinish(_ impulsePlayerView: ImpulsePlayerView) {
        print("onFinish")
    }
    
    func onError(_ impulsePlayerView: ImpulsePlayerView, message: String) {
        print("onError: \(message)")
    }
}
```

### Buttons

The player can be further extended by adding custom buttons. These will be attached to the given position.

```swift
impulsePlayer.removeButton(key: "autoplay")
impulsePlayer.setButton(
    key: "autoplay",
    playerButton: PlayerButton(
        position: .topEnd,
        icon: .add,
        title: "Autoplay"
    ) {
        print("Auto play clicked")
    }
)
```

### Settings

Features can be enabled or disabled via settings. You can customize the default values as follows:

```swift
ImpulsePlayer.setSettings(
    settings: ImpulsePlayerSettings(
        pictureInPictureEnabled: true,  // Default: `false`
        castReceiverApplicationId: "01128E51" // Chromecast receiver application ID; Default: `null` (disabled)
    )
)
```

> **Note**: To enable Picture-in-Picture mode, add the **'Background Modes'** capability in your target's project settings and enable **'Audio, AirPlay, and Picture in Picture'**.

> **Note**: Setting up Chromecast with a custom receiver application ID requires additional configuration. See the section below.

#### Chromecast Setup

To enable Chromecast support in **ImpulsePlayer**, you must configure your **Info.plist** and **Capabilities settings**.

##### 1. Add `NSBonjourServices` to your Info.plist

To allow local network discovery, specify `NSBonjourServices` in your **Info.plist**.

You need to add both `_googlecast._tcp` and `_your-receiver-application-id._googlecast._tcp` as services to ensure proper device discovery.

- The receiver application ID should match the `castReceiverApplicationId` value in `ImpulsePlayerSettings`.
- To set up your own Chromecast receiver ID, follow the [Google Cast Receiver App guide](https://developers.google.com/cast/docs/web_receiver).

**Example:** Update the following definition in **Info.plist**, replacing `01128E51` with your app’s receiver ID.

```xml
<key>NSBonjourServices</key>
<array>
  <string>_googlecast._tcp</string>
  <string>_01128E51._googlecast._tcp</string>
</array>
```

##### 2. Add `NSLocalNetworkUsageDescription` to your Info.plist

To ensure a smooth user experience, customize the **Local Network** permission prompt by adding an app-specific message in your **Info.plist**.

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>${PRODUCT_NAME} uses the local network to discover Cast-enabled devices on your Wi-Fi network.</string>
```

This message will be displayed in the **iOS Local Network Access** dialog when prompted.

##### 3. Enable `Access Wi-Fi Information` Capability

To allow Chromecast discovery and connection:

- Enable the **Access Wi-Fi Information** capability in your **Target settings**.
- Ensure that your provisioning profile includes **Access Wi-Fi Information** support. When using Automatic Signing, this is done automatically. Otherwise this can be configured in the [Apple Developer Portal](https://developer.apple.com/).

### Customization

Apply a custom appearance to customize the look of the player.

```swift
ImpulsePlayer.setAppearance(
    appearance: ImpulsePlayerAppearance(
        h3: ImpulsePlayerFont(
            fontType: .customByFamily(familyName: "Inter", bold: true, italic: false),
            size: 16.0
        ),
        h4: ImpulsePlayerFont(
            fontType: .customByName(fontName: "Inter-Regular_SemiBold"),
            size: 14.0
        ),
        s1: ImpulsePlayerFont(
            fontType: .customByName(fontName: "Inter-Regular"),
            size: 12.0
        ),
        l4: ImpulsePlayerFont(
            fontType: .customByName(fontName: "Inter-Regular"),
            size: 14
        ),
        l7: ImpulsePlayerFont(
            fontType: .customByName(fontName: "Inter-Regular"),
            size: 10.0
        ),
        p1: ImpulsePlayerFont(
            fontType: .customByName(fontName: "Inter-Regular"),
            size: 16.0
        ),
        p2: ImpulsePlayerFont(
            fontType: .customByName(fontName: "Inter-Regular"),
            size: 14.0
        ),
        accentColor: .accent
    )
)
```

> **Note**: `fontType` has three options:

- `.customByFamily(familyName: "Inter", bold: true, italic: false)`: Creates a custom font based on a family name with specified traits.
- `.customByName(fontName: "Inter-Regular_SemiBold")`: Creates a custom font based on a font name, falls back to plain system font if unavailable.
- `.system(bold: true, italic: false)`: Creates a system font with specified traits.
