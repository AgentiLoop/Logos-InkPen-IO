import XCTest
@testable import logos_inkpen_io

/// Opening an SVG must give every object its own ID. When two objects share an ID, the second
/// overwrites the first in `snapshot.objects` and both groups point at the same child, so editing
/// one object changes another and the spatial index maps one ID to two places.
final class SVGImportIntegrityTests: XCTestCase {

    private func open(_ svg: String) throws -> VectorDocument {
        try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    /// Every ID referenced by a layer or a group appears exactly once and resolves to an object.
    private func assertUniqueReferences(_ doc: VectorDocument, file: StaticString = #filePath, line: UInt = #line) -> [UUID] {
        var references: [UUID] = []
        for layer in doc.snapshot.layers { references.append(contentsOf: layer.objectIDs) }
        for object in doc.snapshot.objects.values where object.shape.isGroup || object.shape.isClippingGroup {
            references.append(contentsOf: object.shape.memberIDs)
        }
        let duplicates = Dictionary(grouping: references, by: { $0 }).filter { $0.value.count > 1 }.keys
        XCTAssertTrue(duplicates.isEmpty, "IDs referenced more than once: \(Array(duplicates))", file: file, line: line)
        for id in references {
            XCTAssertNotNil(doc.snapshot.objects[id], "Dangling reference \(id)", file: file, line: line)
        }
        return references
    }

    private func leafCount(_ doc: VectorDocument, named name: String) -> Int {
        doc.snapshot.objects.values.filter { $0.shape.name == name }.count
    }

    func testSymbolWithGroupUsedTwiceGetsDistinctChildren() throws {
        let doc = try open("""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="200">
          <defs>
            <symbol id="pair">
              <g>
                <rect x="0" y="0" width="10" height="10" fill="red"/>
                <rect x="20" y="0" width="10" height="10" fill="blue"/>
              </g>
            </symbol>
          </defs>
          <use xlink:href="#pair" x="0" y="0"/>
          <use xlink:href="#pair" x="100" y="50"/>
        </svg>
        """)
        _ = assertUniqueReferences(doc)
        let rects = doc.snapshot.objects.values.filter { !$0.shape.isGroup && $0.shape.name.lowercased().contains("rect") }
        XCTAssertEqual(rects.count, 4, "Each <use> must produce its own copy of the symbol's children")
    }

    func testSecondUseInstanceIsPositionedByUseOffset() throws {
        let doc = try open("""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="200">
          <defs>
            <symbol id="pair">
              <g>
                <rect x="0" y="0" width="10" height="10"/>
                <rect x="20" y="0" width="10" height="10"/>
              </g>
            </symbol>
          </defs>
          <use xlink:href="#pair" x="0" y="0"/>
          <use xlink:href="#pair" x="100" y="50"/>
        </svg>
        """)
        let leaves = doc.snapshot.objects.values.map(\.shape).filter { !$0.isGroup && !$0.path.elements.isEmpty }
        let minXs = Set(leaves.map { Int($0.bounds.minX.rounded()) })
        XCTAssertTrue(minXs.contains(100) || minXs.contains(120), "Second instance should be offset by the <use> x; got \(minXs.sorted())")
    }

    func testPlainGroupsAndShapesHaveUniqueIDs() throws {
        let doc = try open("""
        <svg xmlns="http://www.w3.org/2000/svg" width="300" height="300">
          <g id="outer">
            <g><rect x="0" y="0" width="10" height="10"/><circle cx="50" cy="50" r="5"/></g>
            <g><rect x="100" y="0" width="10" height="10"/><line x1="0" y1="200" x2="200" y2="200" stroke="black"/></g>
          </g>
          <path d="M 10 250 L 60 250 L 60 290 Z"/>
        </svg>
        """)
        let references = assertUniqueReferences(doc)
        XCTAssertGreaterThanOrEqual(references.count, 5)
    }

    func testEditingOneImportedInstanceLeavesTheOtherAlone() throws {
        let doc = try open("""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="200">
          <defs>
            <symbol id="pair">
              <g>
                <rect x="0" y="0" width="10" height="10"/>
                <rect x="20" y="0" width="10" height="10"/>
              </g>
            </symbol>
          </defs>
          <use xlink:href="#pair" x="0" y="0"/>
          <use xlink:href="#pair" x="100" y="50"/>
        </svg>
        """)
        let groups = doc.snapshot.objects.values.filter { $0.shape.isGroup }
        XCTAssertEqual(groups.count, 2)
        guard groups.count == 2 else { return }
        let firstMembers = Set(groups[0].shape.memberIDs)
        let secondMembers = Set(groups[1].shape.memberIDs)
        XCTAssertTrue(firstMembers.isDisjoint(with: secondMembers), "Two imported groups must not share children")
    }
}
