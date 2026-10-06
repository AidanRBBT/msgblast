import XCTest
@testable import msgblastCore

final class DiscoverTests: XCTestCase {
    func testBundledDirectoryContainsOnlyUniqueDirectNumbers() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("msgblast/Resources/Discover/catalog.json"))
        let catalog = try JSONDecoder().decode(DiscoverCatalog.self, from: data)
        XCTAssertEqual(catalog.agents.count, 92)
        XCTAssertEqual(Set(catalog.agents.map(\.number)).count, catalog.agents.count)
        for agent in catalog.agents {
            XCTAssertEqual(agent.smsURL.absoluteString, "sms:" + agent.number)
            XCTAssertTrue(agent.number.hasPrefix("+"))
            XCTAssertTrue(agent.number.dropFirst().allSatisfy(\.isNumber))
            XCTAssertTrue(["http", "https"].contains(agent.website.scheme))
            XCTAssertFalse(agent.name.isEmpty)
            XCTAssertFalse(agent.tagline.isEmpty)
            XCTAssertFalse(agent.categories.isEmpty)
            if let icon = agent.icon {
                XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("msgblast/Resources/Discover/icons/" + icon).path))
            }
        }
        XCTAssertEqual(catalog.agents.first { $0.id == "orchid" }?.number, "+14152999916")
        XCTAssertFalse(catalog.agents.contains { ["poke", "martin", "lindy", "airtap"].contains($0.id) })
    }

    func testDiscoverOnlyShowsPersonalResearchAndShoppingAgents() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(DiscoverCatalog.self, from: Data(contentsOf: root.appendingPathComponent("msgblast/Resources/Discover/catalog.json")))
        XCTAssertEqual(catalog.discoverAgents.count, 27)
        XCTAssertEqual(catalog.filtered(query: "  ORCHID \n", category: nil).map(\.id), ["orchid"])
        XCTAssertTrue(catalog.filtered(query: "+14152999916", category: nil).isEmpty)
        XCTAssertEqual(catalog.filtered(query: "asmi", category: .personal).map(\.id), ["asmi"])
        XCTAssertEqual(catalog.filtered(query: "factual news", category: .research).map(\.id), ["informed-now"])
        XCTAssertEqual(catalog.filtered(query: "personal shopper", category: .shopping).map(\.id), ["ori-2"])
        XCTAssertTrue(catalog.filtered(query: "Orchid", category: .shopping).isEmpty)
        for category in DiscoverCategory.allCases {
            let matches = catalog.filtered(query: "", category: category)
            XCTAssertFalse(matches.isEmpty)
            XCTAssertTrue(matches.allSatisfy { $0.discoverCategory == category })
        }
        for excluded in ["222", "agent-store", "bach-tran", "https-chat-dev", "mage", "gambly-bot", "bo", "sam", "caresupport", "clera", "soar"] {
            XCTAssertFalse(catalog.discoverAgents.contains { $0.id == excluded }, excluded)
        }
        XCTAssertTrue(catalog.filtered(query: "no-such-agent-xyz", category: nil).isEmpty)
    }
    func testKnownAgentsAreFoundWithoutAConversationAndAvoidPartialNames() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(DiscoverCatalog.self, from: Data(contentsOf: root.appendingPathComponent("msgblast/Resources/Discover/catalog.json")))
        let known = KnownAgentContacts(agents: catalog.discoverAgents)
        for name in ["Fo", " szn ", "INSTINCT", "Fo AI", "Instinct (Agent)"] {
            XCTAssertTrue(known.contains(name: name), name)
        }
        for entry in catalog.discoverAgents {
            XCTAssertTrue(known.contains(name: entry.name), entry.name)
        }
        for name in ["Ford", "Szn Smith", "Alex Instinct Jones", "My instinct", "Alex Chen"] {
            XCTAssertFalse(known.contains(name: name), name)
        }
        XCTAssertFalse(known.contains(name: "Renamed contact"))
    }

}
