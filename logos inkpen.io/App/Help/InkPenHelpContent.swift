import Foundation

struct InkPenHelpContent {
    static let pages: [String: HelpPage] = [
        "index": HelpPage(
            title: "Logos InkPen Help",
            content: """
            <h1>Welcome to Logos InkPen</h1>
            <p>Logos InkPen is a powerful vector graphics application for creating logos, icons, and illustrations.</p>

            <h2>Getting Started</h2>
            <ul>
                <li><a href="getting-started">Creating Your First Design</a></li>
                <li><a href="interface">Understanding the Interface</a></li>
                <li><a href="tools">Complete Tools Reference</a></li>
            </ul>

            <h2>Drawing and Design</h2>
            <ul>
                <li><a href="shapes">Creating Shapes</a></li>
                <li><a href="panels">Working with Panels</a></li>
            </ul>

            <h2>Import and Export</h2>
            <ul>
                <li><a href="import">Importing Files (SVG, PDF)</a></li>
                <li><a href="export">Exporting Your Work</a></li>
                <li><a href="formats">Supported File Formats</a></li>
            </ul>

            <h2>Reference</h2>
            <ul>
                <li><a href="shortcuts">Keyboard Shortcuts</a></li>
            </ul>
            """
        ),
        "getting-started": HelpPage(
            title: "Getting Started",
            content: """
            <h1>Getting Started with Logos InkPen</h1>

            <h2>Creating a New Document</h2>
            <p>1. Choose File > New (⌘N)</p>
            <p>2. Select your canvas size</p>
            <p>3. Begin creating!</p>

            <h2>Basic Workflow</h2>
            <ol>
                <li>Select a drawing tool from the toolbar</li>
                <li>Click and drag on the canvas to create shapes</li>
                <li>Use the selection tool to modify shapes</li>
                <li>Apply colors and styles from the panels</li>
                <li>Export your finished design</li>
            </ol>
            """
        ),
        "tools": HelpPage(
            title: "Tools Reference",
            content: """
            <h1>Complete Tools Reference</h1>

            <h2>Selection Tools</h2>
            <ul>
                <li><b>Selection Tool (V)</b> - Select and transform objects</li>
                <li><b>Direct Selection (A)</b> - Edit individual points</li>
            </ul>

            <h2>Drawing Tools</h2>
            <ul>
                <li><b>Pen Tool (P)</b> - Create precise paths</li>
                <li><b>Pencil Tool (N)</b> - Freehand drawing</li>
                <li><b>Brush Tool (B)</b> - Paint with brushes</li>
            </ul>

            <h2>Shape Tools</h2>
            <ul>
                <li><b>Rectangle (R)</b> - Draw rectangles and squares</li>
                <li><b>Ellipse (E)</b> - Draw circles and ovals</li>
                <li><b>Polygon</b> - Create multi-sided shapes</li>
                <li><b>Star</b> - Draw star shapes</li>
            </ul>

            <h2>Text Tools</h2>
            <ul>
                <li><b>Text Tool (T)</b> - Add and edit text</li>
                <li><b>Text on Path</b> - Place text along paths</li>
            </ul>
            """
        ),
        "shortcuts": HelpPage(
            title: "Keyboard Shortcuts",
            content: """
            <h1>Keyboard Shortcuts</h1>

            <h2>File Operations</h2>
            <table>
                <tr><td>New Document</td><td>⌘N</td></tr>
                <tr><td>Open</td><td>⌘O</td></tr>
                <tr><td>Save</td><td>⌘S</td></tr>
                <tr><td>Save As</td><td>⇧⌘S</td></tr>
                <tr><td>Export</td><td>⌘E</td></tr>
            </table>

            <h2>Edit Operations</h2>
            <table>
                <tr><td>Undo</td><td>⌘Z</td></tr>
                <tr><td>Redo</td><td>⇧⌘Z</td></tr>
                <tr><td>Cut</td><td>⌘X</td></tr>
                <tr><td>Copy</td><td>⌘C</td></tr>
                <tr><td>Paste</td><td>⌘V</td></tr>
                <tr><td>Duplicate</td><td>⌘D</td></tr>
            </table>

            <h2>View Operations</h2>
            <table>
                <tr><td>Zoom In</td><td>⌘+</td></tr>
                <tr><td>Zoom Out</td><td>⌘-</td></tr>
                <tr><td>Fit to Window</td><td>⌘0</td></tr>
                <tr><td>Actual Size</td><td>⌘1</td></tr>
            </table>

            <h2>Tool Shortcuts</h2>
            <table>
                <tr><td>Selection</td><td>V</td></tr>
                <tr><td>Direct Selection</td><td>A</td></tr>
                <tr><td>Pen</td><td>P</td></tr>
                <tr><td>Text</td><td>T</td></tr>
                <tr><td>Rectangle</td><td>R</td></tr>
                <tr><td>Ellipse</td><td>E</td></tr>
            </table>
            """
        )
    ]

    static func getPage(_ name: String) -> HelpPage? {
        return pages[name]
    }
}

struct HelpPage {
    let title: String
    let content: String
}
