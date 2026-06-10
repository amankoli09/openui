import Foundation

public struct ComponentDef {
    public let name: String
    public let description: String
    public let signature: String
    public let params: [String]
    
    public init(name: String, description: String, signature: String) {
        self.name = name
        self.description = description
        self.signature = signature
        
        // Extract parameter names from signature, e.g., "Button(label: String, action: String)" -> ["label", "action"]
        // "VStack(children: [Any])" -> ["children"]
        var extractedParams: [String] = []
        if let startRange = signature.range(of: "("), let endRange = signature.range(of: ")", options: .backwards, range: startRange.upperBound..<signature.endIndex) {
            let argsString = String(signature[startRange.upperBound..<endRange.lowerBound])
            let args = argsString.split(separator: ",")
            for arg in args {
                let trimmed = arg.trimmingCharacters(in: .whitespaces)
                if let colonRange = trimmed.range(of: ":") {
                    let paramName = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    extractedParams.append(paramName)
                } else {
                    let parts = trimmed.split(separator: " ")
                    if let first = parts.first {
                        extractedParams.append(String(first).trimmingCharacters(in: .whitespaces))
                    }
                }
            }
        }
        self.params = extractedParams
    }
}

public protocol AnyComponentRenderer {
    // In OpenUISwiftUI we will cast this to AnyView
    func render(props: [String: Any], children: [Any]) -> Any
}

public class ComponentLibrary {
    public private(set) var components: [String: ComponentDef] = [:]
    public var root: String?
    
    public init() {}
    
    public func register(component: ComponentDef) {
        components[component.name] = component
    }
    
    public func setRoot(_ root: String) {
        self.root = root
    }
}
