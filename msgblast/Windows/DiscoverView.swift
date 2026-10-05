import SwiftUI
import AppKit
import msgblastCore

@MainActor
private enum DiscoverResources {
    static let catalog = try? loadCatalog()
    private static var images: [String: NSImage] = [:]
    static var directory: URL? {
        #if SWIFT_PACKAGE
        Bundle.module.resourceURL?.appendingPathComponent("Discover")
        #else
        Bundle.main.resourceURL?.appendingPathComponent("Discover")
        #endif
    }
    private static func loadCatalog() throws -> DiscoverCatalog {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(DiscoverCatalog.self, from: Data(contentsOf: directory.appendingPathComponent("catalog.json")))
    }
    static func image(_ filename: String?) -> NSImage? {
        guard let filename, let directory else { return nil }
        if let image = images[filename] { return image }
        guard let image = NSImage(contentsOf: directory.appendingPathComponent("icons/" + filename)) else { return nil }
        images[filename] = image
        return image
    }
}

struct DiscoverView: View {
    @ObservedObject var model: AppModel
    private let catalog = DiscoverResources.catalog
    @State private var query = ""
    @State private var category: DiscoverCategory?
    @State private var actionError: String?

    var body: some View {
        if let catalog {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Discover").font(.largeTitle.bold())
                        Text("Personal assistants, research, and shopping.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(catalog.discoverAgents.count) agents", systemImage: "bubble.left.and.bubble.right")
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search agents", text: $query)
                        .textFieldStyle(.plain).accessibilityLabel("Search Discover")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).accessibilityLabel("Clear Discover search")
                    }
                }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        categoryButton("All", value: nil)
                        ForEach(DiscoverCategory.allCases, id: \.self) { category in
                            categoryButton(category.rawValue, value: category)
                        }
                    }.padding(.vertical, 3)
                }.scrollIndicators(.hidden)
                let agents = catalog.filtered(query: query, category: category)
                HStack {
                    Text(category?.rawValue ?? "All agents").font(.headline)
                    Text("\(agents.count)").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
                ScrollView {
                    if agents.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .frame(maxWidth: .infinity).padding(.top, 45)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 16)], spacing: 16) {
                            ForEach(agents) { agent in
                                DiscoverAgentCard(agent: agent, added: isAdded(agent), busy: model.busy) {
                                    Task { await add(agent) }
                                }
                            }
                        }.padding(2)
                    }
                }
                HStack {
                    Link("Agent directory", destination: URL(string: "https://www.imessage.store/")!)
                    Spacer()
                    Text("Directory snapshot · \(catalog.importedOn)").foregroundStyle(.secondary)
                }.font(.caption)
            }.padding(24)
                .alert("Could not add agent", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
                    Button("OK") { actionError = nil }
                } message: { Text(actionError ?? "") }
        } else {
            ContentUnavailableView("Discover unavailable", systemImage: "sparkle.magnifyingglass", description: Text("The agent directory could not be loaded from this app. Rebuild msgblast with its Discover resources."))
        }
    }

    private func categoryButton(_ title: String, value: DiscoverCategory?) -> some View {
        Button { category = value } label: {
            Text(title).font(.callout.weight(category == value ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .foregroundStyle(category == value ? .white : .primary)
                .background(category == value ? Color.accentColor : Color(nsColor: .quaternaryLabelColor).opacity(0.25), in: Capsule())
        }.buttonStyle(.plain).accessibilityLabel("Discover category \(title)")
            .accessibilityValue(category == value ? "Selected" : "Not selected")
    }

    private func isAdded(_ agent: DiscoveredAgent) -> Bool {
        let number = ChatResolver.normalize(agent.number)
        return model.state.agents.contains { $0.handles.contains { ChatResolver.normalize($0) == number } }
    }

    private func add(_ entry: DiscoveredAgent) async {
        guard !model.busy, !isAdded(entry) else { return }
        let avatar = entry.icon.flatMap { filename in
            DiscoverResources.directory.flatMap { try? Data(contentsOf: $0.appendingPathComponent("icons/" + filename)) }
        }
        await model.addAgent(Agent(name: entry.name, handles: [entry.number], avatar: avatar))
        if !isAdded(entry) {
            actionError = model.contactStatus.isEmpty ? "This agent could not be added. Try again." : model.contactStatus
        }
    }
}

private struct DiscoverAgentCard: View {
    let agent: DiscoveredAgent
    let added: Bool
    let busy: Bool
    let add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Group {
                    if let image = DiscoverResources.image(agent.icon) {
                        Image(nsImage: image).resizable().scaledToFit()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13).fill(.blue.opacity(0.12))
                            Text(String(agent.name.prefix(1))).font(.title2.bold()).foregroundStyle(.blue)
                        }
                    }
                }.frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 13)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(agent.name).font(.headline).lineLimit(2)
                    Text(agent.discoverCategory?.rawValue ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }.frame(height: 56, alignment: .top)
            Text(displayedTagline).font(.callout).foregroundStyle(.secondary)
                .lineLimit(3).frame(height: 54, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                .help(displayedTagline)
            HStack {
                Button(action: add) { Label(added ? "Added" : "Add", systemImage: added ? "checkmark" : "plus").frame(minWidth: 64) }
                    .buttonStyle(.borderedProminent).disabled(added || busy)
                    .accessibilityLabel(added ? "\(agent.name) added" : "Add \(agent.name)")
                    .help(added ? "Saved in My agents" : "Add to My agents")
                Spacer()
                Link(destination: agent.website) { Label("Website", systemImage: "arrow.up.right") }
                    .font(.callout).accessibilityLabel("\(agent.name) website").help(agent.website.absoluteString)
            }
        }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(.quaternary, lineWidth: 1) }
            .accessibilityElement(children: .contain).accessibilityIdentifier("discover-agent-" + agent.id)
    }
    private var displayedTagline: String {
        agent.tagline.replacingOccurrences(of: "imessage", with: "Messages", options: .caseInsensitive)
    }
}
