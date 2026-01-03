# PolyFixIt

## Project Information
* **App Name**: PolyFixIt
* **GitHub Repository**: [https://github.com/Mjhumaidan16/Poly_FixIt](https://github.com/Mjhumaidan16/Poly_FixIt)
* **Project Goal**: A mobile application to simplify managing and maintaining college facility issues (infrastructure, Wi-Fi, etc) through direct communication between students, technicians, and admins.

---

## Group Members
* **Mohammed Humaidan** - 202202728
* **Hussain Humaidan** - 202304938
* **Salman Ameeri** - 202203227
* **Ali Aljufairi** - 202304898
* **Abdulrahman Abdulla** - 202301682
* **Abdulla Naser** - 202304876

---

## Main Features (Developer + Tester)
| Developer | Main Features (Developed) | Testing Features (Tested) |
| :--- | :--- | :--- |
| **Salman Ameeri** | Repair Request Submission, Rate Workers and Requesters | Request Management, Technician/Maintenance Account Creation |
| **Hussain Humaidan** | Request Management, Technician Account Creation | Repair Request Submission, Rate Workers and Requestors |
| **Abdulrahman Abdulla** | Room Availability, Inventory System | Admin Dashboard with Analytics, User Follow-Up Chat |
| **Ali Aljufairi** | Admin Dashboard, User Follow-Up Chat | Room Availability, Inventory System |
| **Abdulla Naser** | User Notifications, Settings Page | User Auth, Technician Assignment |
| **Mohammed Humaidan** | User Authentication, Technician Assignment | User Notifications, Settings Page |

---

## Extra Features
* **Salman Ameeri**: 
    1. Interactive Request Map View for locating issues geographically.
* **Hussain Humaidan**: 
    1. Google Auth Integration.
    2. OTP verification.
* **Abdulrahman Abdulla**: 
    1. Emergency Alert System.
* **Ali Aljufairi**: 
    1. Admin statistics as pdf file.
* **Abdulla Naser**: 
    1. Guided video for new users.
* **Mohammed Humaidan**: 
    1. Smart Chat.
    2. AI-Enchanced Repair Request.

---

## Design Changes
* **Removed the Duplicate request**: Removed the duplicate request from the admin dashboard.
* **Added pending request**: Added the pending request to the admin dashboard.
* **Added the AVFoundation**: Added the AVFoundation to show off the guided video for the newly created users.
* **Added a chat with AI**: Added a btn in the request list that will redirect the ticketer to an AI based chat.

---

## Libraries, Packages, & External Code
* **AVFoundation**: Used AVFoundation for diplaying the guide video for the new app users.
* **Firebase SDK**: Used for real-time database, authentication, and cloud storage.
* **SMTP**: Used to send OTP verf codes to verif the newly created accounts.
* **MapKit**: For showing a image as a pre-loaded map with a dots overview as a interactive Request Map View for locating issues geographically.
* **GoogleSignIn-iOS**: For sign in and signing up using the pre-logged in google account.
* **FSCalender**: Used to display a calendar view for scheduling, filtering and room availability.
* **DGCharts**: Used for creating interactive and visually appealing charts in the admin dashboard.
* **Cloudinary**: Used for image and media management, including uploading and displaying photos.
* **Gemini Restful API**: Used to handle communication between the user and the AI bot.


---

## Project Setup Instructions
1.  **Clone the Repository**: `git clone https://github.com/Mjhumaidan16/Poly_FixIt.git`
2.  **Add Dependencies in Xcode**:  
`https://github.com/cloudinary/cloudinary_ios.git`  
`https://github.com/WenchaoD/FSCalendar`  
`https://github.com/ChartsOrg/Charts`  
`https://github.com/google/GoogleSignIn-iOS`  
`https://github.com/Kitura/Swift-SMTP`  
`https://github.com/firebase/firebase-ios-sdk`

4.  **Setup Environment**: Ensure you have an active Firebase project link, the `google-services.json`
5.  **Launch**: Run the project usign the xcode IDE
---

## Testing Details
* **Simulators Used**: iPhone 16 Pro.
* **Admin Login Credentials**:
    * **Email**: admin@admin.com
    * **Password**:  Huss_390370855

---

