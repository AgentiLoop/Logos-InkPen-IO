import SwiftUI
import AppKit

func createNaturalNumberBinding(
    getValue: @escaping () -> Double,
    setValue: @escaping (Double) -> Void
) -> Binding<String> {
    return Binding<String>(
        get: {
            let value = getValue()
            return String(value)
        },
        set: { newStringValue in
            if let doubleValue = Double(newStringValue) {
                setValue(doubleValue)
            }
        }
    )
}
