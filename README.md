A playback service for streaming video/audio from local files, remote resources, or embedded content (e.g., YouTube videos).

 **1. Attach the player:**

 - The player view size matches the container view.
 - Only one item can play at a time; playing a new item pauses others.
 - Previous players are removed from the container when a new player is attached.
 ```
 let playbackItem = PlaybackItem(type: .video, contentString: videoURLString, tag: tag)
 playbackService.attachPlayer(to: videoContainerView, with: playbackItem)
 ```
 You can also manually remove the player:
 `playbackService.removePlayer(from: videoContainerView)`

 Playback starts with user interaction, but you can programmatically pause it:
 `playbackService.pause()`

 To stop the playback and remove the player from the container, call:
 `playbackService.stopPlayer(for: item)` or
 `playbackService.stopAllPlayers()`

 **2. Pause playback when it moves off-screen in a scroll view:**

 Set `playbackService.preferences.shouldAutoPauseVideoOnScrollView` or `shouldAutoPauseAudioOnScrollView` for audio to `true` to pause the playback when the player moves off-screen in a scroll view.

 **3. Adapt to device rotation:**

 If the app only supports portrait mode but you want to autorotate fullscreen when the device orientation changes:
 `playbackService.preferences.orientationsForApplyingRotateTransform = [.landscapeLeft, .landscapeRight, .portraitUpsideDown]`

 If the app supports all orientations, set:
 `playbackService.preferences.orientationsForApplyingRotateTransform = []`

 **4. Customize video presentation view:**

 To customize the video player view, implement a new class that conforms to the `VideoPresentable` protocol and set it to `playbackService.preferences.videoPresentationViewType`.

 **5 Customize playback control view:**

 To customize the playback control view, implement a new class that conforms to the `PlaybackControllable` protocol and set it to `playbackService.preferences.videoControlType` or `audioControlType` for audio.

 **6. Customize playback control plugins:**

 To customize the playback control plugins, create a new type that conforms to the `PlayerPluginSet` protocol and set it to `playbackService.videoPlayerPluginSet` and `audioPlayerPluginSet` for audio.

 **7 Customize item parser:**

 To customize the item parser, implement a new class that conforms to the `PlaybackItemParseable` protocol and add it to `PlaybackURLManager.shared.additionalParsers`.
 
 **8. Directly use the player:**

 If you want to manage the player yourself and do not want the player to be reused or removed when not needed, you can directly use the `HybridMediaPlayer` or `EmbedVideoPlayer`, which provide direct playback functionality.