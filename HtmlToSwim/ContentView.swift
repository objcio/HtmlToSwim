//
//  ContentView.swift
//  HTMLToSwim
//
//  Created by Chris Eidhof on 03.06.21.
//

import SwiftUI
import SwiftSoup

//extension String {
//    var replaceERBBlocks: String {
//        let regex = try! NSRegularExpression(pattern: "<%(.*?)%>", options: .dotMatchesLineSeparators)
//        _ = self as NSString
//        let range = NSRange(self.startIndex..<self.endIndex, in: self)
//        let template = "<!-- $1 -->"
//        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: template)
//    }
//}

extension String {
    var asQuotedSwiftString: String {
        if contains("\n") {
            return "\n#\"\"\"\n\(self)\n\"\"\"#"
        } else if contains("\"") {
            return "#\"\(self)\"#"
        } else {
            return "\"\(self)\""
        }
    }
}

let urlProperties: Set<String> = [
    "src",
    "href",
    "url",
    "action",
    "srcset",
]

extension String {
    func isCustomAttribute(nodeName: String) -> Bool {
        hasPrefix("data") ||
        hasPrefix("aria") ||
        (nodeName == "style" && self == "type") ||
        (nodeName == "meta" && self == "property")
    }
}

func simplify(_ c: [XMLNode]) -> [XMLNode] {
    guard c.count == 1 else { return c }
//    guard let el = c[0] as? XMLElement else { return c }
    let node = c[0]
    guard node.kind == .text else { return c }
    if node.stringValue!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return []
    }
    return c
}

extension String {
    var prettyPath: String {
        if self == "index.html" { return "/" }
        if isRelative, hasSuffix(".html") {
            return "\(dropLast(5))"
        }
        return self
    }
}


extension StringProtocol {
    var isAbsolute: Bool {
        hasPrefix("http") || hasPrefix("/")
    }

    var isRelative: Bool {
        !isAbsolute && !hasPrefix("#")
    }
}

extension Attribute {
    var quotedValue: String {
        absoluteValue.asQuotedSwiftString
    }
    var absoluteValue: String {
        let value = getValue().prettyPath

        if getKey() == "srcset" {
            return value.split(separator: ",").map {
                let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isRelative {
                    return "/\(value)"
                } else {
                    return value
                }
            }.joined(separator: ", ")
        } else if urlProperties.contains(getKey()), value.isRelative {
            return "/\(value)"
        } else {
            return value
        }
    }
}

extension Node {
    func renderToSwim() -> String {
        var result = ""
        r(indent: 0, output: &result)
        return result
    }

    func r<Target: TextOutputStream>(indent: Int = 0, output: inout Target) {
        let indentation = String(repeating: " ", count: indent*4)
        if let e = self as? Element {
            let nodeName = e.tagName()
            let c = e.getChildNodes()

            func writeChildren() {
                for child in c {
                    child.r(indent: indent + 1, output: &output)
                    output.write("\n")
                }
            }
            if nodeName == "#root" {
                writeChildren()
                return
            }
            output.write(indentation + e.tagName())
            output.write("(")
            var first = true



            if let atts = e.getAttributes() {
                var customAttributes: [Attribute] = []
                for a in atts {
                    if a.getKey().isCustomAttribute(nodeName: nodeName) {
                        customAttributes.append(a)
                    }
                }

                for a in atts.sorted(by: { $0.getKey() < $1.getKey() }) {
                    if a.getKey().isCustomAttribute(nodeName: nodeName) { continue }
                    if !first {
                        output.write(", ")
                    }
                    output.write(a.getKey())
                    output.write(": ")
                    output.write(a.quotedValue)
                    first = false
                }

                if !customAttributes.isEmpty {
                    if !first {
                        output.write(", ")
                    }
                    output.write("customAttributes")
                    output.write(": ")
                    let values = customAttributes.map {
                        "\($0.getKey().asQuotedSwiftString): \($0.quotedValue)"
                    }.joined(separator: ", ")
                    output.write("[\(values)]")
                }
            }
            output.write(")")
            if !c.isEmpty {
                output.write(" {\n")
                writeChildren()

//                output.write("\n")
                output.write(indentation + "}")
            }
        } else if let d = self as? DocumentType {
//            return .document
            // do nothing?
        } else if let c = self as? Comment {
            let s = c.getData()
            let lines = s.components(separatedBy: "\n")
            output.write(lines.map { indentation + "// " + $0 }.joined(separator: "\n"))
        } else if let c = self as? TextNode {
            let str = c.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !str.isEmpty {
                output.write(indentation + str.asQuotedSwiftString)
//                output.write("\n")
            }
        } else if let c = self as? DataNode {
            output.write(c.getWholeData().asQuotedSwiftString) // ?
        } else {
            print(self)
            fatalError()
        }
    }
}
//
//extension XMLNode {
//
//    func renderToSwim() -> String {
//        var result = ""
//        r(indent: 0, output: &result)
//        return result
//    }
//
//    func r<Target: TextOutputStream>(indent: Int = 0, output: inout Target) {
//        let indentation = String(repeating: " ", count: indent*4)
//        switch self.kind {
//        case .element:
//            let e = self as! XMLElement
//            output.write(indentation + e.name!)
//            output.write("(")
//            var first = true
//
//
//
//            if let atts = e.attributes {
//                var customAttributes: [XMLNode] = []
//                for a in atts {
//                    if a.name!.isCustomAttribute(nodeName: e.name!) {
//                        customAttributes.append(a)
//                    }
//                }
//
//                for a in atts.sorted(by: { $0.name! < $1.name! }) {
//                    if a.name!.isCustomAttribute(nodeName: e.name!) { continue }
//                    if !first {
//                        output.write(", ")
//                    }
//                    output.write(a.name!)
//                    output.write(": ")
//                    output.write(a.stringValue!.asQuotedSwiftString)
//                    first = false
//                }
//
//                if !customAttributes.isEmpty {
//                    if !first {
//                        output.write(", ")
//                    }
//                    output.write("customAttributes")
//                    output.write(": ")
//                    let values = customAttributes.map {
//                        "\($0.name!.asQuotedSwiftString): \($0.stringValue!.asQuotedSwiftString)"
//                    }.joined(separator: ", ")
//                    output.write("[\(values)]")
//                }
//            }
//            output.write(")")
//            if let c = e.children, !simplify(c).isEmpty {
//                output.write(" {\n")
//                for child in c {
//                    child.r(indent: indent + 1, output: &output)
//                    output.write("\n")
//                }
////                output.write("\n")
//                output.write(indentation + "}")
//            }
//        case .text:
//            let str = self.stringValue!.trimmingCharacters(in: .whitespacesAndNewlines)
//            output.write(indentation + str.asQuotedSwiftString)
//            output.write("\n")
//        case .comment:
//            let s = stringValue!
//            let lines = s.components(separatedBy: "\n")
//            output.write(lines.map { indentation + "// " + $0 }.joined(separator: "\n"))
//        default:
//            output.write("TODO")
//        }
//    }
//}

extension String {
    func swim(tidy: Bool) -> (output: String?, errorMessage: String?) {
//        let str = "<group>\(self)</group>"
        do {
            let doc: Document = try SwiftSoup.parse(self)
            for c in doc.getChildNodes() {
                print(type(of: c))
            }
            return (doc.renderToSwim(), nil)

        } catch {
            var x = ""
            print(error, to: &x)
            return (nil, "\(x)")
        }
    }
}

struct ContentView: View {
    @State var tidy = false
    @State var html: String = """
<div>
  <nav role="navigation" class="nav-menu w-nav-menu">
          <a href="workshops.html" class="nav-link workshops underline-animation w-nav-link">Workshops</a>
          <a href="swift-talks.html" class="nav-link swift-talk underline-animation w-nav-link">Swift Talk</a>
          <a href="books.html" class="nav-link books underline-animation w-nav-link">Books</a>
        </nav>
</div>

<div>
Hello<br>Bye Test &nbsp;
</div>
"""
    var body: some View {
        let message = html.swim(tidy: tidy).output ?? html.swim(tidy: tidy).errorMessage ?? "<unknown error>"
        VStack {
            Toggle("Tidy", isOn: $tidy)
            HSplitView {
                EditorControllerView(text: $html)
                EditorControllerView(text: .constant(message))
            }
        }
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
