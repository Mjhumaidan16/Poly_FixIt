//
//  AVVideoViewController.swift
//  PolyFixIt
//
//  Created by BP-36-212-08 on 28/12/2025.
//


import UIKit
import AVKit
import AVFoundation

class AVVideoViewController: AVPlayerViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let path = Bundle.main.path(forResource: "videoName", ofType: "mp4") {
            let url = URL(fileURLWithPath: path)
            self.player = AVPlayer(url: url)
            self.player?.play()
        }
    }
}