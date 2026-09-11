import AppKit
import DawnSendCore
import SwiftUI

struct MenuBarRootView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppIdentity.displayName)
                .font(.headline)
            Text(AppIdentity.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Work in progress")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Divider()
            Button("Quit DawnSend") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}
