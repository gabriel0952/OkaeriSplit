//
//  AppIntent.swift
//  OkaeriSplitWidget
//

import AppIntents
import WidgetKit

// MARK: - GroupOption AppEntity

struct GroupOption: AppEntity {
    var id: String
    var name: String
    var currency: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "群組"
    static var defaultQuery = GroupOptionsQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

// MARK: - EntityQuery

struct GroupOptionsQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [GroupOption] {
        loadAllGroupOptions().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [GroupOption] {
        loadAllGroupOptions()
    }
}

// MARK: - Widget Configuration Intent

struct SelectGroupsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "選擇顯示的群組"
    static var description = IntentDescription("選擇要在小工具中顯示的群組（最多 3 個）")

    @Parameter(title: "群組", size: [.systemMedium: 3])
    var selectedGroups: [GroupOption]?

    init() {
        self.selectedGroups = nil
    }
}

// MARK: - Helper

private func loadAllGroupOptions() -> [GroupOption] {
    let defaults = UserDefaults(suiteName: "group.com.raycat.okaerisplit")
    guard
        let json = defaults?.string(forKey: "groups_payload"),
        let data = json.data(using: .utf8),
        let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let rawGroups = dict["groups"] as? [[String: Any]]
    else { return [] }

    return rawGroups.compactMap { g -> GroupOption? in
        guard
            let id = g["id"] as? String,
            let name = g["name"] as? String,
            let currency = g["currency"] as? String
        else { return nil }
        return GroupOption(id: id, name: name, currency: currency)
    }
}
