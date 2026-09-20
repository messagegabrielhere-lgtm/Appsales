import SwiftUI

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No habits yet", systemImage: "checkmark.circle")
        } description: {
            Text("Add something small you want to do every day.")
        } actions: {
            Button("Add a habit", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    EmptyStateView {}
}
