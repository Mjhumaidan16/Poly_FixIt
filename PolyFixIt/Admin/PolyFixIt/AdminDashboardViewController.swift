//
//  AdminDashboardViewController.swift
//  SignIn
//
//  Created by BP-36-213-18 on 24/12/2025.
//

import UIKit
import FirebaseFirestore
import DGCharts

final class AdminDashboardViewController: UIViewController {

    private let db = Firestore.firestore()

    private var chartContainers: [UIVisualEffectView] = []

    private let resolutionLineChart = LineChartView()
    private let requestsByUserBarChart = BarChartView()
    private let ratingBarChart = BarChartView()
    private let locationStackedBarChart = BarChartView()

    override func viewDidLoad() {
        super.viewDidLoad()

        chartContainers = findFourChartContainersInOrder()
        setupChartsInContainers()
        fetchRequestsAndRenderCharts()
    }
}

// MARK: - Finding containers
private extension AdminDashboardViewController {

    func findFourChartContainersInOrder() -> [UIVisualEffectView] {
        guard let stack = findFirstStackView(in: view) else { return [] }
        let ves = stack.arrangedSubviews.compactMap { $0 as? UIVisualEffectView }
        if ves.count >= 4 { return Array(ves.prefix(4)) }

        let all = findAllVisualEffectViews(in: view)
        if all.count >= 4 { return Array(all.prefix(4)) }
        return []
    }

    func findFirstStackView(in root: UIView) -> UIStackView? {
        if let s = root as? UIStackView { return s }
        for sub in root.subviews {
            if let found = findFirstStackView(in: sub) { return found }
        }
        return nil
    }

    func findAllVisualEffectViews(in root: UIView) -> [UIVisualEffectView] {
        var result: [UIVisualEffectView] = []
        if let v = root as? UIVisualEffectView { result.append(v) }
        for sub in root.subviews {
            result.append(contentsOf: findAllVisualEffectViews(in: sub))
        }
        return result
    }
}

// MARK: - Setup charts UI
private extension AdminDashboardViewController {

    func setupChartsInContainers() {
        guard chartContainers.count == 4 else { return }

        embedChart(resolutionLineChart, in: chartContainers[0], title: "Resolution Time (Assigned → Completed)")
        embedChart(requestsByUserBarChart, in: chartContainers[1], title: "Requests Submitted by User")
        embedChart(ratingBarChart, in: chartContainers[2], title: "Rating Overview")
        embedChart(locationStackedBarChart, in: chartContainers[3], title: "Location-based Requests Volume")
    }

    func embedChart(_ chart: UIView, in vfx: UIVisualEffectView, title: String) {
        let container = vfx.contentView
        container.subviews.forEach { $0.removeFromSuperview() }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.numberOfLines = 2

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chart.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(chart)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            chart.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            chart.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            chart.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            chart.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        if let c = chart as? ChartViewBase {
            c.noDataText = "No data"
            c.legend.enabled = true
            c.chartDescription.enabled = false
        }
    }
}

// MARK: - Firestore
private extension AdminDashboardViewController {

    struct RequestRow {
        let id: String
        let createdAt: Date?
        let assignedAt: Date?
        let completionTime: Date?
        let submittedByPath: String?
        let ratingLabel: String?
        let campus: String?
        let building: String?
        let room: String?
        let selectedCategory: String?
    }

    func fetchRequestsAndRenderCharts() {
        db.collection("requests").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            let docs = snapshot?.documents ?? []
            let rows = docs.map { self.parseRequest(doc: $0) }

            self.renderResolutionLine(rows)
            self.renderRequestsByUserBar(rows)
            self.renderRatingOverviewBar(rows)
            self.renderLocationStacked(rows)
        }
    }

    func parseRequest(doc: QueryDocumentSnapshot) -> RequestRow {
        let data = doc.data()

        func ts(_ k: String) -> Date? {
            (data[k] as? Timestamp)?.dateValue()
        }

        let submittedByPath = (data["submittedBy"] as? DocumentReference)?.path
        let ratingLabel = (data["rate"] as? [String: Any])?["rating"] as? String

        let loc = data["location"] as? [String: Any]
        let campus = (loc?["campus"] as? [String])?.first
        let building = (loc?["building"] as? [String])?.first
        let room = (loc?["room"] as? [String])?.first

        return RequestRow(
            id: doc.documentID,
            createdAt: ts("createdAt"),
            assignedAt: ts("assignedAt"),
            completionTime: ts("completionTime"),
            submittedByPath: submittedByPath,
            ratingLabel: ratingLabel,
            campus: campus,
            building: building,
            room: room,
            selectedCategory: data["selectedCategory"] as? String
        )
    }
}

// MARK: - Charts
private extension AdminDashboardViewController {

    func renderResolutionLine(_ rows: [RequestRow]) {
        let points = rows.compactMap { r -> (Date, Double)? in
            guard let a = r.assignedAt, let c = r.completionTime else { return nil }
            return (c, c.timeIntervalSince(a) / 3600)
        }

        guard !points.isEmpty else { return }

        let entries = points.enumerated().map {
            ChartDataEntry(x: Double($0.offset), y: $0.element.1)
        }

        let ds = LineChartDataSet(entries: entries, label: "Resolution (hours)")
        ds.valueFont = .systemFont(ofSize: 10)

        resolutionLineChart.data = LineChartData(dataSet: ds)
        resolutionLineChart.rightAxis.enabled = false
    }

    //ONLY CHANGE IS HERE
    func renderRequestsByUserBar(_ rows: [RequestRow]) {
        var counts: [String: Int] = [:]
        rows.forEach { counts[$0.submittedByPath ?? ""] = (counts[$0.submittedByPath ?? ""] ?? 0) + 1 }

        let top = counts.sorted { $0.value > $1.value }.prefix(10)

        let entries = top.enumerated().map {
            BarChartDataEntry(x: Double($0.offset), y: Double($0.element.value))
        }

        let data = BarChartData(dataSet: BarChartDataSet(entries: entries, label: "Requests"))
        requestsByUserBarChart.data = data

        //HIDE X-AXIS LABELS COMPLETELY
        let xAxis = requestsByUserBarChart.xAxis
        xAxis.drawLabelsEnabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false

        requestsByUserBarChart.rightAxis.enabled = false
        requestsByUserBarChart.leftAxis.axisMinimum = 0
    }

    func renderRatingOverviewBar(_ rows: [RequestRow]) {
        let labels = ["Excellent", "Good", "Poor"]
        var counts = ["Excellent": 0, "Good": 0, "Poor": 0]
        var scores: [Double] = []

        for r in rows {
            guard let l = r.ratingLabel else { continue }
            counts[l, default: 0] += 1
            scores.append(l == "Excellent" ? 3 : l == "Good" ? 2 : 1)
        }

        let avg = scores.reduce(0, +) / Double(scores.count)

        let entries = labels.enumerated().map {
            BarChartDataEntry(x: Double($0.offset), y: Double(counts[$0.element]!))
        }

        ratingBarChart.data = BarChartData(
            dataSet: BarChartDataSet(entries: entries, label: "Avg \(String(format: "%.2f", avg))/3")
        )
    }

    func renderLocationStacked(_ rows: [RequestRow]) {
        let categories = ["IT", "pluming", "HVAC", "Furniture", "Safety"]
        var map: [String: [String: Int]] = [:]

        // Build campus → category → count
        rows.forEach {
            let campus = $0.campus ?? "Unknown"
            let cat = $0.selectedCategory ?? ""
            map[campus, default: [:]][cat, default: 0] += 1
        }

        let campuses = map.keys.sorted()

        let entries: [BarChartDataEntry] = campuses.enumerated().map { index, campus in
            let yValues = categories.map { category in
                Double(map[campus]?[category] ?? 0)
            }

            return BarChartDataEntry(
                x: Double(index),
                yValues: yValues
            )
        }

        let ds = BarChartDataSet(entries: entries, label: "Requests")
        ds.stackLabels = categories

        locationStackedBarChart.data = BarChartData(dataSet: ds)
    }

}
