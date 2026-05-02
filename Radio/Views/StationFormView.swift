import SwiftUI

struct StationFormView: View {
    @Binding var stationName: String
    @Binding var stationURL: String
    let isEditing: Bool
    let showValidationError: Bool
    let canSubmit: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L10n.stationNamePlaceholder, text: $stationName)
            TextField("https://example.com/stream", text: $stationURL)

            if showValidationError {
                Text(L10n.stationValidationError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button(L10n.actionCancel, action: onCancel)

                Spacer()

                Button(isEditing ? L10n.string(L10n.actionSave) : L10n.string(L10n.actionAdd), action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
            }
        }
    }
}
