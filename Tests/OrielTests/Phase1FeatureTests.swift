import XCTest
@testable import Oriel

final class Phase1FeatureTests: XCTestCase {
    func testSearchEngineSuggestionURLs() {
        for engine in SearchEngine.allCases {
            let url = engine.suggestionURL(for: "oriel browser")
            XCTAssertNotNil(url, engine.displayName)
            XCTAssertTrue(url!.absoluteString.contains("oriel") || url!.absoluteString.contains("q="), engine.displayName)
        }
    }

    func testBookmarkFoldersAndExportRoundTrip() async {
        await MainActor.run {
            let store = BookmarkStore()
            // Work on isolated data: clear by removing all root items
            for item in store.rootItems {
                store.remove(id: item.id)
            }
            let folder = store.addFolder(title: "News")
            store.add(title: "Example", url: URL(string: "https://example.com/phase1")!, parentID: folder.id)
            XCTAssertEqual(store.children(of: folder.id).count, 1)
            let html = store.exportHTML()
            XCTAssertTrue(html.contains("News"))
            XCTAssertTrue(html.contains("example.com/phase1"))

            for item in store.rootItems {
                store.remove(id: item.id)
            }
            let imported = store.importHTML(html)
            XCTAssertGreaterThanOrEqual(imported, 1)
            XCTAssertFalse(store.bookmarks.filter(\.isFolder).isEmpty)
        }
    }

    func testTabGroupsPersistInSnapshot() async {
        await MainActor.run {
            let manager = TabManager(searchEngine: .duckDuckGo, restoring: nil)
            let group = manager.createGroup(name: "Work", colorName: "ocean")
            let tab = manager.createTab(url: URL(string: "https://example.com"), select: true)
            manager.assign(tabID: tab.id, toGroup: group.id)
            let snapshot = manager.makeSessionSnapshot()
            XCTAssertEqual(snapshot.groups.count, 1)
            XCTAssertEqual(snapshot.tabs.first(where: { $0.id == tab.id })?.groupID, group.id)

            let restored = TabManager(searchEngine: .duckDuckGo, restoring: snapshot)
            XCTAssertEqual(restored.groups.count, 1)
            XCTAssertEqual(restored.tabs.first(where: { $0.id == tab.id })?.groupID, group.id)
        }
    }

    func testFireClearOptionsDefault() {
        let options = FireClearOptions.default
        XCTAssertTrue(options.history)
        XCTAssertTrue(options.cookiesAndSiteData)
        XCTAssertTrue(options.downloads)
        XCTAssertFalse(options.closeTabs)
    }
}
