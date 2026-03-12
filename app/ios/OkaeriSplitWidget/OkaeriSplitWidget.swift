//
//  OkaeriSplitWidget.swift
//  OkaeriSplitWidget
//

import WidgetKit
import SwiftUI

// MARK: - Data Models

struct GroupItem: Identifiable {
    let id: String
    let name: String
    let currency: String
}

// MARK: - Load Data from App Group

func loadGroupsPayload() -> [GroupItem] {
    let defaults = UserDefaults(suiteName: "group.com.raycat.okaerisplit")
    guard
        let json = defaults?.string(forKey: "groups_payload"),
        let data = json.data(using: .utf8),
        let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let rawGroups = dict["groups"] as? [[String: Any]]
    else { return [] }

    return rawGroups.compactMap { g -> GroupItem? in
        guard
            let id = g["id"] as? String,
            let name = g["name"] as? String,
            let currency = g["currency"] as? String
        else { return nil }
        return GroupItem(id: id, name: name, currency: currency)
    }
}

// MARK: - Timeline Provider

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), groups: [
            GroupItem(id: "1", name: "日本旅行", currency: "TWD"),
            GroupItem(id: "2", name: "室友帳本", currency: "TWD"),
        ])
    }

    func snapshot(for configuration: SelectGroupsIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), groups: resolvedGroups(for: configuration))
    }

    func timeline(for configuration: SelectGroupsIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), groups: resolvedGroups(for: configuration))
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func resolvedGroups(for configuration: SelectGroupsIntent) -> [GroupItem] {
        let all = loadGroupsPayload()
        guard let selected = configuration.selectedGroups, !selected.isEmpty else {
            return Array(all.prefix(2))
        }
        let allIds = Set(all.map { $0.id })
        return selected.prefix(2).compactMap { opt in
            guard allIds.contains(opt.id) else { return nil }
            return GroupItem(id: opt.id, name: opt.name, currency: opt.currency)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let groups: [GroupItem]
}

// MARK: - Widget View

struct OkaeriSplitWidgetEntryView: View {
    var entry: Provider.Entry

    // Defined inside the struct to avoid any module-level name conflicts
    static let purple = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OkaeriSplitWidgetEntryView.purple)
                Text("OkaeriSplit")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Separator
            Color(.separator)
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            // Content
            if entry.groups.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 22))
                            .foregroundColor(OkaeriSplitWidgetEntryView.purple.opacity(0.45))
                        Text("開啟 App 建立群組")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entry.groups.enumerated()), id: \.element.id) { index, group in
                        GroupRowView(group: group)
                        if index < entry.groups.count - 1 {
                            Color(.separator)
                                .frame(height: 0.5)
                                .padding(.leading, 58)
                        }
                    }
                }
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Group Row

struct GroupRowView: View {
    let group: GroupItem

    static let purple = Color(red: 0.31, green: 0.27, blue: 0.90)

    private var initial: String { String(group.name.prefix(1)) }

    private var addExpenseURL: URL? {
        URL(string: "com.raycat.okaerisplit://add-expense?groupId=\(group.id)")
    }

    var body: some View {
        HStack(spacing: 12) {

            // Avatar — neutral fill, no per-group colour
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemFill))
                    .frame(width: 36, height: 36)
                Text(initial)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(.label))
            }

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(group.currency)
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()

            // Add expense button
            if let url = addExpenseURL {
                Link(destination: url) {
                    ZStack {
                        Circle()
                            .fill(GroupRowView.purple)
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Widget Configuration

struct OkaeriSplitWidget: Widget {
    let kind: String = "OkaeriSplitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectGroupsIntent.self, provider: Provider()) { entry in
            OkaeriSplitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("OkaeriSplit")
        .description("快速記帳，隨時查看群組")
        .supportedFamilies([.systemMedium])
    }
}
