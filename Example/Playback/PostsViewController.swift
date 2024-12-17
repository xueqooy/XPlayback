//
//  PostsViewController.swift
//  Playback-Demo
//
//  Created by xueqooy on 2022/12/20.
//

import XKit
import Playback
import SnapKit
import UIKit
import Combine

enum PostContent {
    case text(String)
    case video(VideoResource)
    case audio(AudioResource)

    var contentString: String {
        switch self {
        case let .text(content):
            return content
        case let .video(resource):
            return resource.contentString
        case let .audio(resource):
            return resource.contentString
        }
    }

    var format: String? {
        switch self {
        case .text:
            return nil
        case let .video(resource):
            return resource.format
        case let .audio(resource):
            return resource.format
        }
    }
    
    var title: String {
        switch self {
        case .text:
            return contentString
        case let .video(resource):
            return resource.rawValue
        case let .audio(resource):
            return resource.rawValue
        }
    }
    
    var resource: (any Resource)? {
        switch self {
        case .text:
            return nil
        case let .video(resource):
            return resource
        case let .audio(resource):
            return resource
        }
    }
}

struct Post {
    let id: String = UUID().uuidString
    let poster: String
    let content: PostContent
}

class PostsViewController: UITableViewController {
    private let posters = [
        "九文龙",
        "将天生",
        "阿坤",
        "小结巴",
        "鸡哥",
        "陈浩南",
        "大飞",
        "山鸡",
        "乌鸦",
    ]

    private let contents: [PostContent] = VideoResource.allCases.map { .video($0) } + AudioResource.allCases.map { .audio($0) } + [
        .text("黑社会怎么了？出了什么事我自己抗。"),
        .text("你能抗？出了什么事还不是你的兄弟替你抗，还不是我在替你抗。"),
        .text("我们出来混的，本来就打打杀杀，就是为了混口饭吃！"),
        .text("出来混，迟早要还的"),
        .text("兄弟是做一辈子的！"),
        .text("我相信我的兄弟是做错事不是做坏事。我扛！"),
        .text("在每个地方应该有两种秩序，一种是法制秩序，另一种就是属于我们的地下秩序"),
        .text("你滚吧，你加入了黑社会，我不是你的爸爸"),
        .text("黑社会怎么了？出了什么事我自己抗。"),
        .text("你能抗？出了什么事还不是你的兄弟替你"),
    ]

    private lazy var posts: [Post] = generatePosts()
    
    private var viewStateObservation: AnyCancellable?

    static func instantiate() -> PostsViewController {
        let viewController = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(withIdentifier: "PostsViewController") as! PostsViewController
        viewController.commonInit()
        return viewController
    }

    deinit {
        Task { @MainActor in
            PlaybackService.shared.stopAllPlayers()
        }
    }

    func commonInit() {
        tableView.register(TextPostCell.self, forCellReuseIdentifier: "Text")
        tableView.register(VideoPostCell.self, forCellReuseIdentifier: "Video")
        tableView.register(AudioPostCell.self, forCellReuseIdentifier: "Audio")
        
        let reloadButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadPosts))
        navigationItem.rightBarButtonItem = reloadButtonItem
                
        viewStateObservation = viewStatePublisher
            .dropFirst()
            .sink { [weak self] viewState in
                guard let self, viewState == .willAppear else { return }
                
                self.reloadVisibleVideoCell()
            }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        PlaybackService.shared.pauseAllPlayers()
    }
    
    private func generatePosts() -> [Post] {
        (0 ..< 20).map { _ in
            let poster = posters.randomElement()!
            let content = contents.randomElement()!
            return Post(poster: poster, content: content)
        }
    }
    
    @objc private func reloadPosts() {
        posts = generatePosts()
        tableView.reloadData()
    }
    
    private func reloadVisibleVideoCell() {
        // Reload visible video cells to reattach player
        tableView.visibleCells
            .filter { $0 is VideoPostCell || $0 is AudioPostCell }
            .forEach { cell in
                guard let cell = cell as? PostBaseCell, let currentPost = cell.currentPost else {
                    return
                }
                
                cell.render(currentPost)
            }
    }
    

    // MARK: - TableView Delegate & DataSource

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        posts.count
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let post = posts[indexPath.row]
        let cell: UITableViewCell
        switch post.content {
        case .text:
            cell = tableView.dequeueReusableCell(withIdentifier: "Text", for: indexPath)
        case .video:
            cell = tableView.dequeueReusableCell(withIdentifier: "Video", for: indexPath)
        case .audio:
            cell = tableView.dequeueReusableCell(withIdentifier: "Audio", for: indexPath)
        }
        (cell as! PostBaseCell).render(post)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let post = posts[indexPath.row]
        
        
        if let resource = post.content.resource {
            let detailViewController = PlayerViewController.instantiate(resource: resource, postId: post.id)
            navigationController?.pushViewController(detailViewController, animated: true)
        }
    }
}
