import XCTest
@testable import OpenUILang

final class OpenUILangTests: XCTestCase {
    func testParser() throws {
        let parser = Parser()
        let result = parser.parse("root = Text(text: \"Hello\")")
        
        XCTAssertNotNil(result.root)
        XCTAssertEqual(result.root?.typeName, "Text")
        XCTAssertEqual(result.root?.props["text"] as? String, "Hello")
    }
    
    func testPromptGenerator() throws {
        let library = ComponentLibrary()
        library.register(component: ComponentDef(name: "Text", description: "Text display", signature: "Text(text: String)"))
        let prompt = PromptGenerator.generatePrompt(library: library)
        
        XCTAssertTrue(prompt.contains("Text(text: String): Text display"))
    }
}
