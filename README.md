XPlayback is a hybrid media player designed to play audio, video, and embedded videos (e.g., YouTube Embed).

## Features

- **Audio and Video Playback:** Play audio and video from files or network resources.
- **Embedded Video playback:** Play embedded videos from platforms like YouTube.
- **Customizable Engine:** Modify the playback engine to suit your needs.
- **Customizable Control Layer:** Tailor the control interface to your preferences.
- **Plugin Architecture:** Extend functionality with plugins.
- **Screen Rotation Adaptation:** Automatically adapt to screen orientation changes.
- **Gesture Controls:** Utilize single tap, double tap, long press, and drag gestures for intuitive control.
- **Fullscreen Playback:** Enjoy media in fullscreen mode.
- **Seeking Video Preview:** Preview video thumbnails while seeking.

## Usage

 **1. Attach the player:**

 - The player view size matches the container view.
 - Only one item can play at a time; playing a new item pauses others.
 - Previous players are removed from the container when a new player is attached.
 ```swift
 let playbackItem = PlaybackItem(type: .video, contentString: videoURLString, tag: tag)
 playbackService.attachPlayer(to: videoContainerView, with: playbackItem)
 ```
 You can also manually remove the player:
 ```swift
 playbackService.removePlayer(from: videoContainerView)
 ```

 Playback starts with user interaction, but you can programmatically pause it:
 ```swift
 playbackService.pause()
 ```

 To stop the playback and remove the player from the container, call:
 ```swift
 playbackService.stopPlayer(for: item) 
 playbackService.stopAllPlayers()
 ```

 **2. Pause playback when the player moves off-screen in a scroll view:**
 ```swift
 // for video
 playbackService.preferences.shouldAutoPauseVideoOnScrollView = true
 // for audio
 playbackService.preferences.shouldAutoPauseAudioOnScrollView = true
 ```

 **3. Adapt to device rotation:**

 If the app only supports portrait mode but you want to autorotate fullscreen when the device orientation changes:
 ```swift
 playbackService.preferences.orientationsForApplyingRotateTransform = [.landscapeLeft, .landscapeRight, .portraitUpsideDown]
 ```

 If the app supports all orientations, set:
 ```swift
 playbackService.preferences.orientationsForApplyingRotateTransform = []
 ```

 **4. Customize video presentation view:**

 To customize the video player view, implement a new class that conforms to the `VideoPresentable` protocol and set it to 
 ```swift
 playbackService.preferences.videoPresentationViewType
 ```

 **5 Customize playback control view:**

 To customize the playback control view, implement a new class that conforms to the `PlaybackControllable` protocol and set it to 
 ```swift
 // for video
 playbackService.preferences.videoControlType
 // for audio
 playbackService.preferences.audioControlType
 ```

 **6. Customize playback control plugins:**

 To customize the playback control plugins, create a new type that conforms to the `PlayerPluginSet` protocol and set it to 
 ```swift
 // for video
 playbackService.videoPlayerPluginSet
 // for audio
 playbackService.audioPlayerPluginSet 
 ``` 

 **7 Customize item parser:**

 To customize the item parser, implement a new class that conforms to the `PlaybackItemParseable` protocol and add it to 
 ```swift
 PlaybackURLManager.shared.additionalParsers
```
 
 **8. Directly use the player:**

 If you want to manage the player yourself and do not want the player to be reused or removed when not needed, you can directly use the `HybridMediaPlayer` or `EmbedVideoPlayer`, which provide direct playback functionality.

 ```swift
 // Play video or audio
 let hint = PlaybackHint(format: media.format, title: resource.title)
 let engineType: PlayerEngineType = media.isAVPlayerSupportedFormat ? .av : .vlc
 let player: HybridMediaPlayer = media.isAudio ? .defaultAudioPlayer(engineType: engineType) : .defaultVideoPlayer(engineType: engineType)
 player.hint = hint
 player.url = media.url
 player.containerView = contaienrView
 
 // Play youtube embed video
 let player = EmbedVideoPlayer()
 player.url = youtubeEmbedURL
 player.containerView = contaienrView
 ```

## Run Examples

The local media file for Example can be configured using the `Resource.swift` file. To add a local file, place it in the sample directory and name it according to the enumeration value. For remote resources, simply define the enumeration value with the `rawValue` being the resource URL.

## Snapshot

![截屏2024-12-17 15 23 17](https://github.com/user-attachments/assets/edff0a96-0439-4cbe-b4f1-779d387fb51e)

![截屏2024-12-17 15 26 03](https://github.com/user-attachments/assets/187758c3-6a16-41bc-beae-2dbf4ffe0f75)

![截屏2024-12-17 15 23 39](https://github.com/user-attachments/assets/542e1ded-f6e6-485a-b15a-9abdf56c6a2e)

## Note

This repository does not provide any installation methods like CocoaPods or Swift Package Manager. You are free to copy the codebase and make any custom modifications as per your requirements.

## License

XPlayback is licensed under the MIT License. See [LICENSE](LICENSE) for more information.

## Contact

- GitHub: [https://github.com/xueqooy/XKit](https://github.com/xueqooy/XKit)
- Email: xue_qooy@163.com

