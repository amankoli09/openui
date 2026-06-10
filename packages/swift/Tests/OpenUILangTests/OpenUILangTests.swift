import XCTest
@testable import OpenUILang

final class OpenUILangTests: XCTestCase {
    func testParserWithPositionalArgs() throws {
        let library = ComponentLibrary()
        library.register(component: ComponentDef(name: "Button", description: "Clickable button", signature: "Button(label: String, action: String)"))
        
        let parser = Parser(library: library)
        let result = parser.parse("root = Button(\"Submit\", \"submit:signup\")")
        
        XCTAssertNotNil(result.root)
        XCTAssertEqual(result.root?.typeName, "Button")
        XCTAssertEqual(result.root?.props["label"] as? String, "Submit")
        XCTAssertEqual(result.root?.props["action"] as? String, "submit:signup")
    }
    
    func testParserWithReferences() throws {
        let library = ComponentLibrary()
        library.register(component: ComponentDef(name: "Stack", description: "Stack", signature: "Stack(children: [Any])"))
        library.register(component: ComponentDef(name: "Text", description: "Text display", signature: "Text(text: String)"))
        
        let parser = Parser(library: library)
        let text = """
        root = Stack([header])
        header = Text("Hello Nested")
        """
        let result = parser.parse(text)
        
        XCTAssertNotNil(result.root)
        XCTAssertEqual(result.root?.typeName, "Stack")
        
        let children = result.root?.props["children"] as? [Any]
        XCTAssertNotNil(children)
        XCTAssertEqual(children?.count, 1)
        
        if let child = children?.first as? ElementNode {
            XCTAssertEqual(child.typeName, "Text")
            XCTAssertEqual(child.props["text"] as? String, "Hello Nested")
        } else {
            XCTFail("Child is not an ElementNode")
        }
    }
    
    func testParserWithDynamicSyntax() throws {
        let library = ComponentLibrary()
        library.register(component: ComponentDef(name: "Text", description: "Text display", signature: "Text(text: String)"))
        
        let parser = Parser(library: library)
        let text = """
        $isLoading = true
        root = Text($isLoading ? "Loading..." : "Ready")
        """
        let result = parser.parse(text)
        
        XCTAssertNotNil(result.root)
        XCTAssertEqual(result.root?.typeName, "Text")
        // "text" property should hold the dynamic placeholder for now, since we aren't fully evaluating it in materialized props
        XCTAssertEqual(result.root?.props["text"] as? String, "$ternary")
        
        XCTAssertNotNil(result.stateDeclarations)
    }
    
    func testPromptGenerator() throws {
        let library = ComponentLibrary()
        library.register(component: ComponentDef(name: "Text", description: "Text display", signature: "Text(text: String)"))
        let prompt = PromptGenerator.generatePrompt(library: library)
        
        XCTAssertTrue(prompt.contains("Text(text: String): Text display"))
    }
}
