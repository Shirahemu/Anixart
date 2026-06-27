import SwiftUI

struct ProfileWatchDynamicsView: View {
    let dynamics: [ProfileWatchDynamic]

    private var points: [WatchDynamicPoint] {
        Self.normalizedPoints(from: dynamics)
    }

    var body: some View {
        GeometryReader { geometry in
            let maxCount = max(points.map(\.count).max() ?? 0, 1)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.14))
                            .frame(height: 0.5)
                        Spacer(minLength: 0)
                    }
                    Rectangle()
                        .fill(Color.secondary.opacity(0.14))
                        .frame(height: 0.5)
                }
                .padding(.bottom, 22)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(points) { point in
                        VStack(spacing: 6) {
                            Text("\(point.count)")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)

                            Capsule()
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: 10)
                                .frame(height: barHeight(for: point.count, maxCount: maxCount, availableHeight: geometry.size.height - 48))
                                .frame(maxHeight: .infinity, alignment: .bottom)

                            Text(point.dayLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 150)
    }

    private func barHeight(for count: Int, maxCount: Int, availableHeight: CGFloat) -> CGFloat {
        let baseline: CGFloat = 6
        guard count > 0 else { return baseline }
        return max(baseline, CGFloat(count) / CGFloat(maxCount) * max(availableHeight, baseline))
    }

    private static func normalizedPoints(from dynamics: [ProfileWatchDynamic]) -> [WatchDynamicPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let fallbackDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: today)
        }
        let items = Array(dynamics.prefix(7))

        return fallbackDates.enumerated().map { index, fallbackDate in
            let item = index < items.count ? items[index] : nil
            let date = parsedDate(from: item?.date?.value) ?? fallbackDate
            return WatchDynamicPoint(
                id: "\(index)-\(dayFormatter.string(from: date))",
                dayLabel: dayFormatter.string(from: date),
                count: item?.count ?? 0
            )
        }
    }

    private static func parsedDate(from rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let timestamp = TimeInterval(rawValue), timestamp > 1_000_000 {
            return Date(timeIntervalSince1970: timestamp)
        }

        for formatter in inputFormatters {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }

        return nil
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd"
        return formatter
    }()

    private static let inputFormatters: [DateFormatter] = {
        ["yyyy-MM-dd", "dd.MM.yyyy", "yyyy/MM/dd", "dd.MM"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = format
            return formatter
        }
    }()
}

private struct WatchDynamicPoint: Identifiable {
    let id: String
    let dayLabel: String
    let count: Int
}
