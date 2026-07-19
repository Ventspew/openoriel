import XCTest
@testable import Oriel

final class ExtensionStoreCatalogTests: XCTestCase {
    func testParseAMOSearchResults() throws {
        let json = """
        {
          "count": 1,
          "results": [
            {
              "slug": "ublock-origin",
              "name": { "en-US": "uBlock Origin" },
              "summary": { "en-US": "Finally, an efficient blocker." },
              "type": "extension",
              "icon_url": "https://addons.mozilla.org/user-media/addon_icons/607/607454-64.png",
              "ratings": { "average": 4.5 }
            }
          ]
        }
        """.data(using: .utf8)!
        let items = ExtensionStoreCatalog.parseAMOSearch(data: json, kind: .extension)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].source, .firefox)
        XCTAssertEqual(items[0].storeIdentifier, "ublock-origin")
        XCTAssertEqual(items[0].name, "uBlock Origin")
        XCTAssertEqual(items[0].kind, .extension)
        XCTAssertEqual(items[0].rating, 4.5)
    }

    func testParseChromeStoreHTMLCards() {
        let html = """
        <div class="Cb7Kte" data-item-id="cjpalhdlnbpafiamejdnhcphjbkeiagm">
          <a href="/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm">x</a>
          <div>uBlock Origin</div>
          <p>Finally, an efficient blocker. Easy on CPU and memory.</p>
        </div>
        <div class="Cb7Kte" data-item-id="ddkjiahejlhfcafbddmgiahcphecmpfh">
          <a href="/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh">x</a>
          <div>uBlock Origin Lite</div>
          <span>Featured</span>
        </div>
        """
        let items = ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].source, .chrome)
        XCTAssertEqual(items[0].storeIdentifier, "cjpalhdlnbpafiamejdnhcphjbkeiagm")
        XCTAssertEqual(items[0].name, "uBlock Origin")
        XCTAssertTrue(items[0].storeURL?.absoluteString.contains("ublock-origin") == true)
        XCTAssertEqual(items[1].name, "uBlock Origin Lite")
    }

    func testInvalidChromeIDsIgnored() {
        let html = #"<div data-item-id="not-a-valid-id-here-at-all!!!!">Nope</div>"#
        XCTAssertTrue(ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension).isEmpty)
    }
}
