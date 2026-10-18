import AppKit
import SwiftUI
import ClipboardCore

struct TextPreview: View {
    let presentation: TextPresentation
    @PreviewState private var showOriginal = false

    init(text: String) { presentation = TextPresentation(text) }

    var body: some View {
        VStack(spacing: 0) {
            LinkedTextView(text: showOriginal ? presentation.original : presentation.formatted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text("\(presentation.original.count.formatted()) characters · \(presentation.format.rawValue)")
                Spacer()
                if presentation.format != .text {
                    Toggle("Original", isOn: $showOriginal).toggleStyle(.switch).controlSize(.mini)
                        .help("Show the original clipboard text, including comments. Copy and Save to always use the original.")
                }
            }.font(.caption).foregroundStyle(.secondary).padding(14)
        }
    }
}

private typealias PreviewState<Value> = SwiftUI.State<Value>

/// AppKit's text system wraps long URLs and supports native link clicks and selection.
private struct LinkedTextView: NSViewRepresentable {
    let text: String

    final class Coordinator {
        var renderedText: String?
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        let view = NSTextView(frame: scroll.contentView.bounds)
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = false
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainerInset = NSSize(width: 24, height: 24)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width,
                                                  height: CGFloat.greatestFiniteMagnitude)
        view.linkTextAttributes = [.foregroundColor: NSColor.linkColor,
                                   .underlineStyle: NSUnderlineStyle.single.rawValue]
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard context.coordinator.renderedText != text,
              let view = scroll.documentView as? NSTextView else { return }
        context.coordinator.renderedText = text
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 3
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph
        ])
        context.coordinator.detector?.enumerateMatches(in: text,
            range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            if let match, let url = match.url {
                attributed.addAttribute(.link, value: url, range: match.range)
            }
        }
        view.textStorage?.setAttributedString(attributed)
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.scrollToBeginningOfDocument(nil)
    }
}
