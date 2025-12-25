import UIKit

class MainTabBarViewController: UITabBarController, UITabBarControllerDelegate {

    // The custom menu view
    private let customMenuView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let dimmingView = UIView()
    private var isMenuVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        setupCustomMenu()
    }

    private func setupCustomMenu() {
                customMenuView.layer.cornerRadius = 16
                customMenuView.layer.masksToBounds = true // Required for corner radius on blur
                customMenuView.translatesAutoresizingMaskIntoConstraints = false
                customMenuView.alpha = 0
                
                customMenuView.layer.borderWidth = 0.5
                customMenuView.layer.borderColor = UIColor.separator.cgColor

                let btn1 = createMenuButton(title: "Settings", icon: "gearshape.fill", tag: 5)
                let btn2 = createMenuButton(title: "Inventory", icon: "AdminTechnician", tag: 4)
                
                let stack = UIStackView(arrangedSubviews: [btn1, btn2])
                stack.axis = .vertical
                stack.distribution = .fillEqually
                stack.translatesAutoresizingMaskIntoConstraints = false
                
                customMenuView.contentView.addSubview(stack)
                view.addSubview(customMenuView)

                NSLayoutConstraint.activate([
                    customMenuView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                    customMenuView.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -12),
                    customMenuView.widthAnchor.constraint(equalToConstant: 70),
                    customMenuView.heightAnchor.constraint(equalToConstant: 120),
                    
                    stack.topAnchor.constraint(equalTo: customMenuView.contentView.topAnchor),
                    stack.bottomAnchor.constraint(equalTo: customMenuView.contentView.bottomAnchor),
                    stack.leadingAnchor.constraint(equalTo: customMenuView.contentView.leadingAnchor),
                    stack.trailingAnchor.constraint(equalTo: customMenuView.contentView.trailingAnchor)
                ])
    }

    private func createMenuButton(title: String, icon: String, tag: Int) -> UIButton {
        var config = UIButton.Configuration.plain()

                var titleAttr = AttributedString(title)
                titleAttr.font = .systemFont(ofSize: 11, weight: .regular)
                config.attributedTitle = titleAttr
                
                config.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17))
                config.imagePlacement = .top // Places image above text
                config.imagePadding = 6      // Space between image and text
                
                config.baseForegroundColor = .label
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
                
                let button = UIButton(configuration: config)
                button.tag = tag
                button.addTarget(self, action: #selector(menuButtonTapped(_:)), for: .touchUpInside)
                
                return button
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let index = viewControllers?.firstIndex(of: viewController)
        
        if index == 3 {
            toggleMenu()
            return false
        } else {
            if isMenuVisible { toggleMenu() }
            return true
        }
    }

    @objc private func toggleMenu() {
        isMenuVisible.toggle()
        
        UIView.animate(withDuration: 0.3, delay: 0) {
            self.customMenuView.alpha = self.isMenuVisible ? 1 : 0
            self.customMenuView.transform = self.isMenuVisible ? .identity : CGAffineTransform(translationX: 0, y: 20)
        }
    }

    @objc private func menuButtonTapped(_ sender: UIButton) {
        toggleMenu() // Hide menu after selection
        
        // Handle your navigation here, e.g.:
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let nextVC: UIViewController?

            // Use the tag to determine which screen to load
            switch sender.tag {
            case 5:
                nextVC = storyboard.instantiateViewController(withIdentifier: "SettingsAccount")
            case 4:
                nextVC = storyboard.instantiateViewController(withIdentifier: "InventoryView")
            default:
                return
            }

            if let vc = nextVC {
                // Option A: Push (If inside a Navigation Controller)
                if let nav = storyboard.instantiateViewController(withIdentifier: "mainNavController") as? UINavigationController {
                    nav.pushViewController(vc, animated: true)
                }
                // Option B: Present (Fallback if no nav controller exists)
                else {
                    self.present(vc, animated: true)
                }
            }
    }
}
