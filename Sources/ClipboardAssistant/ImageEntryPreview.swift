import AppKit
import SwiftUI
import ClipboardCore

private typealias ImagePreviewState<Value> = SwiftUI.State<Value>

struct ImageEntryPreview: View {
    let entry: ClipboardEntry
    let image: NSImage
    @ObservedObject var monitor: ClipboardMonitor
    var didCopyText: (() -> Void)? = nil
    @ImagePreviewState private var showText = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Preview", selection: $showText) {
                    Text("Image").tag(false)
                    Text("Text").tag(true)
                }.pickerStyle(.segmented).frame(width: 160)
                Spacer()
                if let text = entry.recognizedText, !text.isEmpty {
                    Button { monitor.copyText(text); didCopyText?() } label: {
                        Label("Copy text", systemImage: "text.viewfinder")
                    }.help("Copy recognized text without adding another history item")
                }
            }.padding(12)
            Divider()
            if showText {
                if let text = entry.recognizedText, !text.isEmpty {
                    TextPreview(text: text)
                } else if monitor.recognitionFailures.contains(entry.id) {
                    VStack(spacing: 10) {
                        Text("Text could not be recognized.").foregroundStyle(.secondary)
                        Button("Try again") { monitor.retryRecognition(entry.id) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                } else {
                    Text(entry.recognizedText == nil
                         ? (monitor.capturePreferences.recognizeTextInImages
                            ? "Recognizing text on this Mac…" : "Enable image text recognition in Settings.")
                         : "No text found in this image.")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                }
            } else {
                Image(nsImage: image).resizable().scaledToFit()
                    .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onDrag { EntryDragProvider.make(for: entry) }
            }
            Divider()
            HStack {
                Text("PNG · \(ByteCountFormatter.string(fromByteCount: Int64(entry.imageData?.count ?? 0), countStyle: .file))")
                Spacer()
                if entry.recognizedText != nil { Text("Text recognized on device") }
            }.font(.caption).foregroundStyle(.secondary).padding(12)
        }.id(entry.id)
    }
}
