//
//  ContentView.swift
//  HTMLToSwim
//
//  Created by Chris Eidhof on 03.06.21.
//

import SwiftUI

extension String {
    var replaceERBBlocks: String {
        let regex = try! NSRegularExpression(pattern: "<%(.*?)%>", options: .dotMatchesLineSeparators)
        _ = self as NSString
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        let template = "<!-- $1 -->"
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: template)
    }
}

extension String {
    var asQuotedSwiftString: String {
        return "\"\(self)\""
    }
}

extension XMLNode {
    func renderToSwim() -> String {
        var result = ""
        r(indent: 0, output: &result)
        return result
    }
    
    func r<Target: TextOutputStream>(indent: Int = 0, output: inout Target) {
        let indentation = String(repeating: " ", count: indent*4)
        switch self.kind {
        case .element:
            let e = self as! XMLElement
            output.write(indentation + e.name!)
            output.write("(")
            var first = true
            
            if let atts = e.attributes {
                for a in atts.sorted(by: { $0.name! < $1.name! }) {
                    if !first {
                        output.write(", ")
                    }
                    output.write(a.name!)
                    output.write(": ")
                    output.write(a.stringValue!.asQuotedSwiftString)
                    first = false
                }
            }
            output.write(")")
            if let c = e.children, !c.isEmpty {
                output.write(" {\n")
                for child in c {
                    child.r(indent: indent + 1, output: &output)
                    output.write("\n")
                }
                output.write("\n")
                output.write(indentation + "}")
            }
        case .text:
            let str = self.stringValue!
            output.write(indentation + str.asQuotedSwiftString)
        case .comment:
            let s = stringValue!
            let lines = s.components(separatedBy: "\n")
            output.write(lines.map { indentation + "// " + $0 }.joined(separator: "\n"))
        default:
            output.write("TODO")
        }
    }
}

extension String {
    var swim: (output: String?, errorMessage: String?) {
        let str = "<group>\(self.replaceERBBlocks)</group>"
        do {
            let x = try XMLDocument(xmlString: str, options: [])
            return (x.rootElement()?.renderToSwim(), nil)
        } catch {
            var x = ""
            print(error, to: &x)
            return (nil, "\(x)")
        }
    }
}

struct ContentView: View {
    @State var html: String = "<bar /><em class=\"foo\">Emphasis</em>"
    var body: some View {
        let message = html.swim.output ?? html.swim.errorMessage ?? "<unknown error>"
        HSplitView {
            EditorControllerView(text: $html)
                .frame(maxWidth: .infinity)
            EditorControllerView(text: .constant(message))
        }
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
