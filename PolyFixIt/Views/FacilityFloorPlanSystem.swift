import SwiftUI
import UIKit

// MARK: - 1. Building Definitions
enum CampusBuilding: String, CaseIterable {
    case engineering = "Building 19, 10, 35"
    case library     = "Central Library, 60, 20"
    case cafeteria   = "Student Cafe, 45, 75"
    case adminOffice = "Admin Block, 80, 50"

    var data: (name: String, x: CGFloat, y: CGFloat) {
        let components = self.rawValue.components(separatedBy: ", ")
        let name = components[0]
        let xValue = CGFloat(Double(components[1]) ?? 0) / 100.0
        let yValue = CGFloat(Double(components[2]) ?? 0) / 100.0
        return (name, xValue, yValue)
    }
}

// MARK: - 2. Data Model
struct FacilityIssue: Identifiable {
    let id = UUID()
    let building: CampusBuilding
    let color: Color
}

// MARK: - 3. SwiftUI Overlay
struct PinOverlayView: View {
    var issues: [FacilityIssue]
    var onTap: (FacilityIssue) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear // Non-interactive background
                
                ForEach(issues) { issue in
                    // THE FIX: Move the Button inside a container and
                    // force a small frame on the button itself.
                    Button(action: { }) {
                        VStack(spacing: 2) {
                            Text(issue.building.data.name)
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(3)

                            Circle()
                                .fill(issue.color)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                    // 1. Use PlainButtonStyle to stop the system from adding extra "room"
                    .buttonStyle(PlainButtonStyle())
                    // 2. Explicitly frame the button to a small size
                    .frame(width: 60, height: 40)
                    // 3. Ensure hit testing only happens where content is
                    .contentShape(Rectangle())
                    .position(
                        x: issue.building.data.x * geometry.size.width,
                        y: issue.building.data.y * geometry.size.height
                    )
                }
            }
        }
    }
}

// MARK: - 4. UIKit ViewController
class FacilityMapViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    let activeIssues = [
        FacilityIssue(building: .engineering, color: .red),
        FacilityIssue(building: .cafeteria, color: .orange),
        FacilityIssue(building: .library, color: .blue),
        FacilityIssue(building: .adminOffice, color: .red)
    ]

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupOverlay()
    }

    private func setupOverlay() {
        view.subviews.filter { $0.accessibilityLabel == "Overlay" }.forEach { $0.removeFromSuperview() }

        let overlay = PinOverlayView(issues: activeIssues) { [weak self] issue in
            self?.handlePinTap(issue)
        }
        
        let hostingController = UIHostingController(rootView: overlay)
        hostingController.view.backgroundColor = .clear
        hostingController.view.accessibilityLabel = "Overlay"
        
        // Critical for precise hit testing
        hostingController.view.isUserInteractionEnabled = true
        
        addChild(hostingController)
        scrollView.addSubview(hostingController.view)
        hostingController.view.frame = imageView.frame
        hostingController.didMove(toParent: self)
    }

    private func handlePinTap(_ issue: FacilityIssue) {
        let alert = UIAlertController(title: "Precise Tap", message: issue.building.data.name, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
