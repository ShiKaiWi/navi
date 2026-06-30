import SwiftUI
import AppKit

/// A plain-text editor backed by `NSTextView`.
///
/// SwiftUI's `TextEditor` enables macOS "smart" substitutions (curly quotes,
/// em-dashes) with no way to turn them off, which corrupts JSON as you type.
/// It also offers no control over the text-container insets, so an overlaid
/// placeholder never lines up with the real cursor. This wrapper fixes both:
/// it disables every automatic substitution and exposes a known inset that the
/// placeholder can match exactly. It also scrolls large documents smoothly.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// Inset applied inside the text container. The placeholder uses the same
    /// values so it sits exactly where the first character will appear.
    static let textInset = CGSize(width: 5, height: 8)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.font = font
        textView.isRichText = false
        textView.allowsUndo = true

        // The whole point of this view: no surprise text rewriting.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        textView.textContainerInset = Self.textInset
        textView.drawsBackground = false
        scrollView.drawsBackground = false

        // Don't wrap: let JSON lines extend and scroll horizontally.
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        scrollView.hasHorizontalScroller = true

        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Only replace the contents on external changes (e.g. Sample / Clear),
        // never while the user is the source of the edit — that would reset the
        // selection and fight the typing.
        if textView.string != text {
            textView.string = text
        }
        if textView.font != font {
            textView.font = font
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: PlainTextEditor

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
