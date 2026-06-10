import Foundation

public class Parser {
    private var input: String
    private var index: String.Index
    public var library: ComponentLibrary?
    
    public init(library: ComponentLibrary? = nil) {
        self.input = ""
        self.index = "".startIndex
        self.library = library
    }
    
    public func parse(_ text: String) -> ParseResult {
        self.input = text
        self.index = text.startIndex
        
        var statements: [Statement] = []
        var context: [String: ASTNode] = [:]
        
        while index < input.endIndex {
            skipWhitespace()
            guard index < input.endIndex else { break }
            
            if input[index] == "$" {
                advance()
                if let id = parseIdentifier() {
                    skipWhitespace()
                    if match("=") {
                        skipWhitespace()
                        if let expr = parseExpression() {
                            statements.append(.state(id: id, initExpr: expr))
                            context[id] = expr
                        }
                    }
                }
            } else if let id = parseIdentifier() {
                skipWhitespace()
                if match("=") {
                    skipWhitespace()
                    if let expr = parseExpression() {
                        if case let .comp(name, _, _) = expr, name == "Query" {
                            statements.append(.query(id: id, call: CallNode(callee: name, args: []), expr: expr, deps: nil))
                        } else if case let .comp(name, _, _) = expr, name == "Mutation" {
                            statements.append(.mutation(id: id, call: CallNode(callee: name, args: []), expr: expr))
                        } else {
                            statements.append(.value(id: id, expr: expr))
                            context[id] = expr
                        }
                    }
                }
            } else {
                // Skip unparseable tokens
                index = input.index(after: index)
            }
        }
        
        var rootNode: ElementNode? = nil
        let entryId = statements.first(where: {
            if case let .value(id, _) = $0 { return id == "root" }
            return false
        }) != nil ? "root" : statements.first(where: { 
            if case .value = $0 { return true }
            return false
        }).flatMap { 
            if case let .value(id, _) = $0 { return id }
            return nil
        }
        
        if let entryId = entryId, let rootExpr = context[entryId] {
            rootNode = materialize(rootExpr, context: context, statementId: entryId)
        }
        
        let meta = ParseResultMeta(incomplete: false, unresolved: [], orphaned: [], statementCount: statements.count, errors: [])
        return ParseResult(root: rootNode, meta: meta, stateDeclarations: [:], queryStatements: [], mutationStatements: [])
    }
    
    private func parseExpression() -> ASTNode? {
        guard let primary = parsePrimaryExpression() else { return nil }
        
        skipWhitespace()
        if match("?") {
            skipWhitespace()
            guard let thenExpr = parseExpression() else { return primary }
            skipWhitespace()
            if match(":") {
                skipWhitespace()
                guard let elseExpr = parseExpression() else { return primary }
                return .ternary(cond: primary, then: thenExpr, else: elseExpr)
            }
        }
        
        return primary
    }
    
    private func parsePrimaryExpression() -> ASTNode? {
        skipWhitespace()
        if index >= input.endIndex { return nil }
        
        let c = input[index]
        if c == "\"" {
            return .str(parseString())
        } else if c == "[" {
            return .arr(parseArray())
        } else if c == "$" {
            advance()
            if let ident = parseIdentifier() {
                return .stateRef(ident)
            }
            return nil
        } else if c.isNumber {
            return .num(parseNumber())
        } else if input[index...].hasPrefix("true") {
            advance(by: 4); return .bool(true)
        } else if input[index...].hasPrefix("false") {
            advance(by: 5); return .bool(false)
        } else if let ident = parseIdentifier() {
            skipWhitespace()
            if match("(") {
                let args = parseArguments()
                return .comp(name: ident, args: args.0, mappedProps: args.1)
            } else {
                return .ref(ident)
            }
        }
        return nil
    }
    
    private func parseString() -> String {
        advance() // skip "
        var result = ""
        while index < input.endIndex && input[index] != "\"" {
            result.append(input[index])
            advance()
        }
        if index < input.endIndex { advance() } // skip "
        return result
    }
    
    private func parseNumber() -> Double {
        var result = ""
        while index < input.endIndex && (input[index].isNumber || input[index] == ".") {
            result.append(input[index])
            advance()
        }
        return Double(result) ?? 0
    }
    
    private func parseArray() -> [ASTNode] {
        advance() // skip [
        var elements: [ASTNode] = []
        while index < input.endIndex {
            skipWhitespace()
            if match("]") { break }
            if let expr = parseExpression() {
                elements.append(expr)
            }
            skipWhitespace()
            _ = match(",")
        }
        return elements
    }
    
    private func parseArguments() -> ([ASTNode], [String: ASTNode]) {
        var args: [ASTNode] = []
        var props: [String: ASTNode] = [:]
        
        while index < input.endIndex {
            skipWhitespace()
            if match(")") { break }
            
            let startIdx = index
            if let ident = parseIdentifier() {
                skipWhitespace()
                if match(":") {
                    skipWhitespace()
                    if let expr = parseExpression() {
                        props[ident] = expr
                    }
                } else {
                    index = startIdx
                    if let expr = parseExpression() {
                        args.append(expr)
                    }
                }
            } else {
                if let expr = parseExpression() {
                    args.append(expr)
                }
            }
            
            skipWhitespace()
            _ = match(",")
        }
        
        return (args, props)
    }
    
    private func parseIdentifier() -> String? {
        guard index < input.endIndex, input[index].isLetter || input[index] == "_" else { return nil }
        var result = ""
        while index < input.endIndex && (input[index].isLetter || input[index].isNumber || input[index] == "_") {
            result.append(input[index])
            advance()
        }
        return result
    }
    
    private func skipWhitespace() {
        while index < input.endIndex && input[index].isWhitespace {
            advance()
        }
    }
    
    private func match(_ str: String) -> Bool {
        if input[index...].hasPrefix(str) {
            advance(by: str.count)
            return true
        }
        return false
    }
    
    private func advance(by count: Int = 1) {
        index = input.index(index, offsetBy: count, limitedBy: input.endIndex) ?? input.endIndex
    }
    
    private func materialize(_ node: ASTNode, context: [String: ASTNode], statementId: String? = nil) -> ElementNode? {
        switch node {
        case let .ref(ident):
            if let refNode = context[ident] {
                return materialize(refNode, context: context, statementId: ident)
            }
            return nil
        case let .comp(name, args, mappedProps):
            var propsMap: [String: Any] = [:]
            var finalMappedProps = mappedProps ?? [:]
            
            if let library = self.library, let compDef = library.components[name] {
                for (i, arg) in args.enumerated() {
                    if i < compDef.params.count {
                        let paramName = compDef.params[i]
                        if finalMappedProps[paramName] == nil {
                            finalMappedProps[paramName] = arg
                        }
                    }
                }
            } else {
                // If no library is provided, fallback to "children" for the first arg if it's an array
                if args.count > 0 && finalMappedProps["children"] == nil {
                    finalMappedProps["children"] = args[0]
                }
            }
            
            for (k, v) in finalMappedProps {
                if let val = materializeValue(v, context: context) {
                    propsMap[k] = val
                }
            }
            return ElementNode(statementId: statementId, typeName: name, props: propsMap, partial: false)
        default:
            return nil
        }
    }
    
    private func materializeValue(_ node: ASTNode, context: [String: ASTNode]) -> Any? {
        switch node {
        case let .str(s): return s
        case let .num(n): return n
        case let .bool(b): return b
        case let .arr(arr): 
            return arr.compactMap { materializeValue($0, context: context) }
        case .comp: 
            if let el = materialize(node, context: context) {
                // For OpenUI Lang, children components are usually wrapped in arrays, but if not we might need it.
                // Just return the element node itself.
                return el
            }
            return nil
        case let .ref(ident):
            if let resolved = context[ident] {
                if case .comp = resolved {
                    return materialize(resolved, context: context, statementId: ident)
                }
                return materializeValue(resolved, context: context)
            }
            return nil
        case let .stateRef(ident):
            return "$\(ident)" // Simplified placeholder for dynamic state
        case .ternary:
            return "$ternary" // Simplified placeholder
        default: return nil
        }
    }
}
