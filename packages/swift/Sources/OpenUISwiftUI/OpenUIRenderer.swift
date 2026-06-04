import SwiftUI
#if canImport(OpenUILang)
import OpenUILang
#endif

public struct OpenUIRenderer: View {
    let node: ElementNode?
    let library: ComponentLibrary

    public init(node: ElementNode?, library: ComponentLibrary) {
        self.node = node
        self.library = library
    }
    
    public var body: some View {
        if let node = node {
            renderNode(node)
        } else {
            AnyView(Text("No UI to render")
                .foregroundColor(.gray))
        }
    }
    
    private func renderNode(_ node: ElementNode) -> AnyView {
        switch node.typeName {
        case "VStack":
            return AnyView(VStack {
                renderChildren(node.props["children"] as? [ElementNode])
            })
        case "HStack":
            return AnyView(HStack {
                renderChildren(node.props["children"] as? [ElementNode])
            })
        case "Text":
            return AnyView(Text((node.props["text"] as? String) ?? ""))
        case "Button":
            return AnyView(Button(action: {
                // Action handling
                print("Button clicked: \(node.props["label"] as? String ?? "")")
            }) {
                Text((node.props["label"] as? String) ?? "Button")
            })
        default:
            return AnyView(Text("Unknown component: \(node.typeName)")
                .foregroundColor(.red))
        }
    }
    
    @ViewBuilder
    private func renderChildren(_ children: [ElementNode]?) -> some View {
        if let children = children {
            ForEach(0..<children.count, id: \.self) { index in
                renderNode(children[index])
            }
        }
    }
}
