//
//  AVVideoViewController.swift
//  PolyFixIt
//
//  Created by BP-36-212-08 on 28/12/2025.
//


import UIKit
import AVKit
import AVFoundation

class AVVideoViewController: UIViewController {

    // المتغيرات الخاصة بالفيديو
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAndPlayVideo()
    }

    func setupAndPlayVideo() {
        // 1. ضع اسم ملف الفيديو الخاص بك هنا (مثلاً "intro" وبدون الامتداد)
        guard let path = Bundle.main.path(forResource: "123", ofType: "mp4") else {
            print("خطأ: لم يتم العثور على ملف الفيديو في المشروع")
            return
        }

        let url = URL(fileURLWithPath: path)
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        
        // 2. جعل الفيديو يملأ الشاشة
        playerLayer?.frame = self.view.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        
        // 3. إضافة طبقة الفيديو خلف الأزرار (في الخلفية)
        if let layer = playerLayer {
            self.view.layer.insertSublayer(layer, at: 0)
        }

        player?.play()

        // 4. مراقبة انتهاء الفيديو للانتقال تلقائياً
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(transitionToNext),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)
    }

    // ربط هذا الأكشن بزر الـ Skip في الـ Storyboard
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        transitionToNext()
    }

    @objc func transitionToNext() {
        // إيقاف المشغل وتفريغه من الذاكرة
        player?.pause()
        player = nil
        
        // الانتقال إلى الصفحة المطلوبة باستخدام الـ Storyboard ID
        // ملاحظة: تأكد أن اسم الـ Storyboard هو "Main" أو غيره حسب مشروعك
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nextVC = storyboard.instantiateViewController(withIdentifier: "EditItemInInventory")
        
        // تغيير الصفحة الجذرية للتطبيق (أفضل للذاكرة في صفحات الـ Splash)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = nextVC
            
            // إضافة تأثير انتقال ناعم
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
        }
    }
    
    // لضمان ضبط مقاس الفيديو إذا تغير اتجاه الجهاز
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = self.view.bounds
    }
}
