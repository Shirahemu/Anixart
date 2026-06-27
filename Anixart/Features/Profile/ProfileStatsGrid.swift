import SwiftUI

struct ProfileStatsGrid: View {
    let profile: Profile

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ProfileMetricTile(title: "смотрю", value: value(profile.watchingCount), systemImage: "play.circle")
                ProfileMetricTile(title: "в планах", value: value(profile.planCount), systemImage: "calendar.badge.plus")
            }

            HStack(spacing: 10) {
                ProfileMetricTile(title: "просмотрено", value: value(profile.completedCount), systemImage: "checkmark.circle")
                ProfileMetricTile(title: "отложено", value: value(profile.holdOnCount), systemImage: "pause.circle")
            }

            ProfileMetricTile(title: "брошено", value: value(profile.droppedCount), systemImage: "xmark.circle")

            HStack(spacing: 10) {
                ProfileMetricTile(title: "эпизоды", value: value(profile.watchedEpisodeCount), systemImage: "film")
                ProfileMetricTile(title: "время", value: profile.watchedHoursText ?? "-", systemImage: "clock")
            }
        }
    }

    private func value(_ value: Int?) -> String {
        value.map(String.init) ?? "-"
    }

    private func value(_ value: Int64?) -> String {
        value.map(String.init) ?? "-"
    }
}
