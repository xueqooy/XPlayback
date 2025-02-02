//
//  PlayerViewController.swift
//  Playback-Demo
//
//  Created by xueqooy on 2022/12/20.
//

import Playback
import PlaybackFoundation
import UIKit

class PlayerViewController: UIViewController {
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var textLabel: UILabel!
    @IBOutlet var videoView: UIView!
    @IBOutlet var audioView: UIView!
    private var resource: (any Resource)?
    private var postId: String?
    private var player: Player?

    static func instantiate(resource: any Resource, postId: String? = nil) -> PlayerViewController {
        let viewController = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(withIdentifier: "PlayerViewController") as! PlayerViewController
        viewController.resource = resource
        viewController.postId = postId
        viewController.title = AVPlayerSupportedFormat.contains(resource.format ?? "") ? "AVPlayer Engine" : "VLCPlayer Engine"
        return viewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: 2000)

        setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        PlaybackService.shared.pauseAllPlayers()

        player?.pause()
    }

    func setup() {
        guard let resource else {
            return
        }

        videoView.isHidden = !resource.isVideo
        audioView.isHidden = !resource.isAudio
        textLabel.text = resource.contentString
        let contaienrView: UIView! = resource.isVideo ? videoView : audioView
        let hint = PlaybackHint(format: resource.format, title: resource.rawValue)

        if let postId {
            // Play using PlaybackService
            Task { @MainActor in
                let item = PlaybackItem(mediaType: resource.isVideo ? .video : .audio, contentString: resource.contentString, tag: postId)
                await PlaybackService.shared.attachPlayer(to: contaienrView, with: item, hint: hint)
            }
        } else {
            // Play using Player
            Task { @MainActor [weak self] in
                let item = PlaybackItem(mediaType: resource.isVideo ? .video : .audio, contentString: resource.contentString)
                guard let urlResult = await PlaybackAssetManager.shared.parse(item), let self else {
                    return
                }

                switch urlResult.asset {
                case let .embed(url):
                    let player =
                        EmbedVideoPlayer()
                    player.url = url
                    player.containerView = contaienrView
                    self.player = player

                case .local, .network:
                    let engineType: BuiltInPlayerEngineType = AVPlayerSupportedFormat.contains(resource.format ?? "") ? .av : .vlc
                    let player: HybridMediaPlayer = resource.isAudio ? .defaultAudioPlayer(engineType: engineType) : .defaultVideoPlayer(engineType: engineType)
                    player.hint = hint
                    player.url = urlResult.asset.url
                    player.containerView = contaienrView
                    self.player = player

                case .localWithMultiQuality, .networkWithMultiQuality:
                    let engineType: BuiltInPlayerEngineType = AVPlayerSupportedFormat.contains(resource.format ?? "") ? .av : .vlc
                    let player: HybridMediaPlayer = resource.isAudio ? .defaultAudioPlayer(engineType: engineType) : .defaultVideoPlayer(engineType: engineType)
                    player.hint = hint
                    player.multiQualityAssetController?.asset = urlResult.asset.mutiQualityAsset
                    player.containerView = contaienrView
                    self.player = player
                }
            }
        }
    }
}
