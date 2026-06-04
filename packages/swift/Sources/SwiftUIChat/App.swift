import SwiftUI
import OpenUILang
import OpenUISwiftUI

@main
struct SwiftUIChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var library = ComponentLibrary()
    @State private var openUIText = ""
    @State private var parsedRoot: ElementNode? = nil
    @State private var prompt = ""
    
    let parser = Parser()
    
    init() {
        var lib = ComponentLibrary()
        lib.register(component: ComponentDef(name: "VStack", description: "Vertical layout container", signature: "VStack(children: [Any])"))
        lib.register(component: ComponentDef(name: "HStack", description: "Horizontal layout container", signature: "HStack(children: [Any])"))
        lib.register(component: ComponentDef(name: "Text", description: "Text display", signature: "Text(text: String)"))
        lib.register(component: ComponentDef(name: "Button", description: "Clickable button", signature: "Button(label: String)"))
        lib.setRoot("VStack")
        _library = State(initialValue: lib)
        _prompt = State(initialValue: PromptGenerator.generatePrompt(library: lib))
    }
    
    var body: some View {
        HStack {
            VStack {
                Text("OpenUI Lang Output")
                    .font(.headline)
                TextEditor(text: $openUIText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.gray, width: 1)
                    .onChange(of: openUIText) { newValue in
                        let result = parser.parse(newValue)
                        self.parsedRoot = result.root
                    }
                
                Button("Simulate Stream") {
                    simulateStream()
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            
            VStack {
                Text("Rendered SwiftUI")
                    .font(.headline)
                
                ScrollView {
                    VStack {
                        if let root = parsedRoot {
                            OpenUIRenderer(node: root, library: library)
                        } else {
                            Text("Awaiting input...")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .border(Color.gray, width: 1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    private func simulateStream() {
        let text = """
        root = VStack(
            children: [
                Text(text: "Hello from OpenUI Lang"),
                HStack(
                    children: [
                        Button(label: "Cancel"),
                        Button(label: "Submit")
                    ]
                )
            ]
        )
        """
        
        openUIText = ""
        parsedRoot = nil
        
        // Simulating streaming tokens
        var delay = 0.0
        let chars = Array(text)
        for char in chars {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.openUIText.append(char)
                let result = parser.parse(self.openUIText)
                if let root = result.root {
                    self.parsedRoot = root
                }
            }
            delay += 0.01
        }
    }
}
