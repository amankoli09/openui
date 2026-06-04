import Foundation

public class Parser {
    private var input: String
    private var index: String.Index
    
    public init() {
        self.input = ""
        self.index = "".startIndex
    }
    
    public func parse(_ text: String) -> ParseResult {
        self.input = text
        self.index = text.startIndex
        
        var statements: [Statement] = []
        
        while index < input.endIndex {
            skipWhitespace()
            guard index < input.endIndex else { break }
            
            if let id = parseIdentifier() {
                skipWhitespace()
                if match("=") {
                    skipWhitespace()
                    if let expr = parseExpression() {
                        statements.append(.value(id: id, expr: expr))
                    }
                }
            } else {
                // Skip unparseable tokens
                index = input.index(after: index)
            }
        }
        
        var rootNode: ElementNode? = nil
        if let rootStmt = statements.first(where: {
            if case let .value(id, _) = $0 { return id == "root" }
            return false
        }) {
            if case let .value(_, expr) = rootStmt {
                rootNode = materialize(expr)
            }
        }
        
        let meta = ParseResultMeta(incomplete: false, unresolved: [], orphaned: [], statementCount: statements.count, errors: [])
        return ParseResult(root: rootNode, meta: meta, stateDeclarations: [:], queryStatements: [], mutationStatements: [])
    }
    
    private func parseExpression() -> ASTNode? {
        skipWhitespace()
        if index >= input.endIndex { return nil }
        
        let c = input[index]
        if c == "\"" {
            return .str(parseString())
        } else if c == "[" {
            return .arr(parseArray())
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
            
            // Try to parse named arg: ident: expr
            let startIdx = index
            if let ident = parseIdentifier() {
                skipWhitespace()
                if match(":") {
                    if let expr = parseExpression() {
                        props[ident] = expr
                    }
                } else {
                    // It was just an expression
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
    
    private func materialize(_ node: ASTNode) -> ElementNode? {
        if case let .comp(name, _, mappedProps) = node {
            var propsMap: [String: Any] = [:]
            if let mProps = mappedProps {
                for (k, v) in mProps {
                    if case let .str(s) = v { propsMap[k] = s }
                    else if case let .num(n) = v { propsMap[k] = n }
                    else if case let .bool(b) = v { propsMap[k] = b }
                    else if case let .arr(arr) = v {
                        propsMap[k] = arr.compactMap { materialize($0) }
                    } else if case .comp = v {
                        if let child = materialize(v) {
                            propsMap[k] = [child] // simplified
                        }
                    }
                }
            }
            return ElementNode(statementId: nil, typeName: name, props: propsMap, partial: false)
        }
        return nil
    }
}
