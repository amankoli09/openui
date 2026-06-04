import Foundation

public struct ComponentDef {
    public let name: String
    public let description: String
    public let signature: String
    
    public init(name: String, description: String, signature: String) {
        self.name = name
        self.description = description
        self.signature = signature
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
