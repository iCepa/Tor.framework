//
//  ViewController.swift
//  Tor-Example
//
//  Created by Benjamin Erhart on 01.12.25.
//  Copyright © 2025 Benjamin Erhart. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(load), name: .init("tor-ready"), object: nil)
    }

    @objc
    func load(_ notification: Notification) {
        let dictionary = notification.object as? [CFString: AnyObject]

        Task { @MainActor in
            let conf = WKWebViewConfiguration()

            if #available(iOS 17.0, macOS 14.0, *), let port = dictionary?[kCFStreamPropertySOCKSProxyPort] as? UInt16 {
                let endpoint = NWEndpoint.hostPort(
                    host: getHost(dictionary?[kCFStreamPropertySOCKSProxyHost] as? String),
                    port: .init(integerLiteral: port))

                conf.websiteDataStore.proxyConfigurations.removeAll()
                conf.websiteDataStore.proxyConfigurations.append(ProxyConfiguration(socksv5Proxy: endpoint))
            }

            webView = WKWebView(frame: .zero, configuration: conf)
            webView.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(webView)
            webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

            webView.load(.init(url: .init(string: "https://check.torproject.org")!))
        }
    }

    private func getHost(_ hostString: String?) -> NWEndpoint.Host {
        if let hostString, !hostString.isEmpty {
            if let ipv4 = IPv4Address(hostString) {
                return .ipv4(ipv4)
            }

            if let ipv6 = IPv6Address(hostString) {
                return .ipv6(ipv6)
            }

            return .name(hostString, nil)
        }

        return .ipv4(.loopback)
    }
}
