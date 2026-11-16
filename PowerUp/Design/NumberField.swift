import SwiftUI

/// Getalveld dat de waarde bij elke toetsaanslag bijwerkt, zodat een set afvinken
/// direct de getypte waarde gebruikt. Accepteert zowel komma als punt.
struct NumberField: View {
    @Binding var value: Double
    var placeholder: String = "0"
    var allowsDecimal = true
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .focused($focused)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, new in
                let parsed = Self.parse(new)
                if parsed != value { value = parsed }
            }
            .onChange(of: value) { _, new in
                if !focused { text = Self.format(new) }
            }
    }

    static func parse(_ string: String) -> Double {
        max(0, Double(string.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    static func format(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

extension Binding where Value == Double {
    /// Koppelt een geheel getal aan een `NumberField`.
    init(int source: Binding<Int>) {
        self.init(get: { Double(source.wrappedValue) }, set: { source.wrappedValue = Int($0) })
    }
}

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
