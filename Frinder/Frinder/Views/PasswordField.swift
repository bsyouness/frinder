import SwiftUI
import UIKit

/// A secure text field that correctly handles iOS AutoFill and strong-password suggestions.
/// SwiftUI's SecureField has a known bug where AutoFill turns the field yellow, makes it
/// non-interactive, and stops rendering the obscured dots. Using UITextField directly avoids this.
struct PasswordField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType = .password

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.isSecureTextEntry = true
        tf.placeholder = placeholder
        tf.textContentType = contentType
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        tf.borderStyle = .roundedRect
        tf.font = UIFont.preferredFont(forTextStyle: .body)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only push external changes (e.g. clearing the field) to avoid fighting with the user's cursor
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PasswordField

        init(_ parent: PasswordField) { self.parent = parent }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        // Capture AutoFill — it fires textFieldDidEndEditing without editingChanged
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
