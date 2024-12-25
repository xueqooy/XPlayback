//
//  DemoListViewController.swift
//  Playback-Demo
//
//  Created by xueqooy on 2022/12/20.
//

import UIKit

class DemoListViewController: UITableViewController {
    struct Demo {
        let title: String
        let resource: (any Resource)?

        init(title: String, resource: (any Resource)? = nil) {
            self.title = title
            self.resource = resource
        }
    }

    private let demos: [Demo] = [
        .init(title: "Posts"),
    ] + VideoResource.allCases.map { .init(title: $0.rawValue, resource: $0) }
        + AudioResource.allCases.map { .init(title: $0.rawValue, resource: $0) }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return demos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let demo = demos[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        if #available(iOS 14.0, *) {
            var contentConfig = UIListContentConfiguration.cell()
            contentConfig.text = demo.title
            cell.contentConfiguration = contentConfig
        } else {
            cell.textLabel?.text = demo.title
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let viewController: UIViewController

        let demo = demos[indexPath.row]
        if demo.resource == nil {
            viewController = PostsViewController.instantiate()
        } else {
            viewController = PlayerViewController.instantiate(resource: demo.resource!)
        }

        navigationController?.pushViewController(viewController, animated: true)
    }

//    override var shouldAutorotate: Bool {
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            return true
//        } else {
//            return false
//        }
//    }
//
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            return [.portrait, .landscapeLeft, .landscapeRight]
//        } else {
//            return .portrait
//        }
//    }
}
