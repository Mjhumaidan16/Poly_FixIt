import SwiftUI
import UIKit

// MARK: - 1. Building Definitions
enum CampusBuilding: String, CaseIterable {
    // Format: "Display Name, X_Percentage, Y_Percentage"
    case engineering = "Engineering Wing, 25, 35"
    case library     = "Central Library, 60, 20"
    case cafeteria   = "Student Cafe, 45, 75"
    case adminOffice = "Admin Block, 80, 50"

    // This function extracts the data from the string automatically
    var data: (name: String, x: CGFloat, y: CGFloat) {
        let components = self.rawValue.components(separatedBy: ", ")
        
        // Extract Name (Index 0)
        let name = components[0]
        
        // Extract X and Y, convert from String to Double, then to CGFloat
        let xValue = CGFloat(Double(components[1]) ?? 0) / 100.0 // Converting 25 to 0.25
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                
                ForEach(issues) { issue in
                    VStack(spacing: 2) {
                        // Optional: Small label showing the building name
                        Text(issue.building.data.name)
                            .font(.system(size: 8, weight: .bold))
                            .padding(2)
                            .background(.white.opacity(0.8))
                            .cornerRadius(4)

                        Circle()
                            .fill(issue.color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    // Positioning using the extracted data
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
    
    @IBOutlet weak var imageView: UIImageView!
    
    // Now you just specify the building name, and the code finds the X,Y automatically
    let activeIssues = [
        FacilityIssue(building: .engineering, color: .red),
        FacilityIssue(building: .cafeteria, color: .red)
    ]

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupOverlay()
    }

    private func setupOverlay() {
        // 1. Remove old overlay if it exists
        view.subviews.filter { $0.accessibilityLabel == "Overlay" }.forEach { $0.removeFromSuperview() }

        let overlay = PinOverlayView(issues: activeIssues)
        let hostingController = UIHostingController(rootView: overlay)
        hostingController.view.backgroundColor = .clear
        hostingController.view.accessibilityLabel = "Overlay"
        
        addChild(hostingController)
        
        // CRITICAL FIX: Add to the scroll view, not the main view
        // Replace 'yourScrollView' with the name of your UIScrollView outlet
        yourScrollView.addSubview(hostingController.view)
        
        // 2. Align the frame exactly to the ImageView's frame
        // This ensures that as the Image expands/moves, the pin layer follows
        hostingController.view.frame = imageView.frame
        
        hostingController.didMove(toParent: self)
    }
}
