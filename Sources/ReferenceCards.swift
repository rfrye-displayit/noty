import AppKit
import SwiftUI

struct ReferenceCard: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let sections: [ReferenceSection]
}

struct ReferenceSection: Identifiable, Hashable {
    let title: String
    let items: [ReferenceItem]

    var id: String { title }
}

struct ReferenceItem: Identifiable, Hashable {
    let title: String
    let command: String
    let detail: String?

    var id: String { "\(title)\u{0}\(command)" }
    var needsCaution: Bool {
        let executable = command.split(separator: " ").first.map(String.init) ?? ""
        return executable == "sudo" || executable == "kill" || executable == "pkill"
    }
}

enum ReferenceCatalog {
    static let terminalID = "builtin.reference.terminal"
    static let terminalKey = "terminal"

    static let terminal = ReferenceCard(
        id: terminalID,
        title: L10n.text("reference.terminal"),
        icon: "terminal",
        sections: [
            ReferenceSection(title: L10n.text("reference.audio"), items: [
                ReferenceItem(title: L10n.text("reference.audio_restart"),
                              command: "sudo killall coreaudiod",
                              detail: L10n.text("reference.audio_restart_detail"))
            ]),
            ReferenceSection(title: L10n.text("reference.system"), items: [
                ReferenceItem(title: L10n.text("reference.system_version"), command: "sw_vers", detail: nil),
                ReferenceItem(title: L10n.text("reference.system_kernel"), command: "uname -a", detail: nil),
                ReferenceItem(title: L10n.text("reference.system_uptime"), command: "uptime", detail: nil),
                ReferenceItem(title: L10n.text("reference.system_disk"), command: "df -h", detail: nil)
            ]),
            ReferenceSection(title: L10n.text("reference.networking"), items: [
                ReferenceItem(title: L10n.text("reference.network_ping"), command: "ping google.com", detail: nil),
                ReferenceItem(title: L10n.text("reference.network_interfaces"), command: "ifconfig", detail: nil),
                ReferenceItem(title: L10n.text("reference.network_wifi_ip"), command: "ipconfig getifaddr en0", detail: nil),
                ReferenceItem(title: L10n.text("reference.network_dns"), command: "nslookup google.com", detail: nil)
            ]),
            ReferenceSection(title: L10n.text("reference.files"), items: [
                ReferenceItem(title: L10n.text("reference.files_current"), command: "pwd", detail: nil),
                ReferenceItem(title: L10n.text("reference.files_list"), command: "ls -la", detail: nil),
                ReferenceItem(title: L10n.text("reference.files_parent"), command: "cd ..", detail: nil),
                ReferenceItem(title: L10n.text("reference.files_mkdir"), command: "mkdir <directory>", detail: nil),
                ReferenceItem(title: L10n.text("reference.files_copy"), command: "cp <source> <destination>", detail: nil),
                ReferenceItem(title: L10n.text("reference.files_move"), command: "mv <source> <destination>", detail: nil)
            ]),
            ReferenceSection(title: L10n.text("reference.processes"), items: [
                ReferenceItem(title: L10n.text("reference.processes_all"), command: "ps aux", detail: nil),
                ReferenceItem(title: L10n.text("reference.processes_top"), command: "top", detail: nil),
                ReferenceItem(title: L10n.text("reference.processes_kill"), command: "kill <PID>", detail: nil),
                ReferenceItem(title: L10n.text("reference.processes_pkill"), command: "pkill <name>", detail: nil)
            ]),
            ReferenceSection(title: L10n.text("reference.search"), items: [
                ReferenceItem(title: L10n.text("reference.search_file"), command: "find . -name \"<name>\"", detail: nil),
                ReferenceItem(title: L10n.text("reference.search_text"), command: "grep -R \"<text>\" .", detail: nil)
            ])
        ])

    static func card(for item: Note) -> ReferenceCard? {
        guard item.kind == .reference else { return nil }
        if item.referenceKey == terminalKey || item.body == terminalKey { return terminal }
        return ReferenceCard(id: item.id, title: item.displayTitle,
                             icon: "doc.text", sections: [])
    }

    @discardableResult
    static func copy(_ command: String,
                     using writer: (String) -> Bool = writeToGeneralPasteboard) -> Bool {
        writer(command)
    }

    private static func writeToGeneralPasteboard(_ command: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(command, forType: .string)
    }
}

struct ReferenceCardView: View {
    let item: Note
    let card: ReferenceCard
    @ObservedObject var deck: DeckModel
    unowned let controller: DeckController
    var onRight: Bool = true

    @State private var copiedCommand: String?
    @State private var clearCopiedWork: DispatchWorkItem?

    private var pal: NoteColor { item.palette }
    private var cardShape: UnevenRoundedRectangle { edgeTabShape(onRight: onRight, radius: 14) }

    var body: some View {
        HStack(spacing: 0) {
            if onRight { gutter; sheet } else { sheet; gutter }
        }
        .frame(width: deck.noteSize.width, height: deck.noteSize.height)
        .background(
            cardShape
                .fill(LinearGradient(colors: [pal.paper, pal.paper.opacity(0.9)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.34), radius: 28,
                        x: onRight ? -12 : 12, y: 12)
        )
        .clipShape(cardShape)
        .overlay(cardShape.strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
        .onDisappear { clearCopiedWork?.cancel() }
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(pal.ink.opacity(0.12))
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if card.sections.isEmpty {
                        Text(L10n.text("reference.unavailable"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(pal.ink.opacity(0.58))
                    } else {
                        ForEach(card.sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: card.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(card.title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button { NoteStore.shared.togglePin(id: item.id) } label: {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(item.pinned ? 0 : 32))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.pinned ? L10n.text("help.unpin") : L10n.text("help.pin"))
            Button { controller.collapse() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.text("action.close"))
        }
        .foregroundStyle(pal.ink.opacity(0.78))
        .padding(.horizontal, 14)
        .frame(height: 36)
    }

    private func sectionView(_ section: ReferenceSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(pal.ink.opacity(0.52))
            ForEach(section.items) { referenceItem in
                commandRow(referenceItem)
            }
        }
    }

    private func commandRow(_ referenceItem: ReferenceItem) -> some View {
        Button { copy(referenceItem.command) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if referenceItem.needsCaution {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange.opacity(0.9))
                    }
                    Text(referenceItem.title)
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                }
                HStack(spacing: 8) {
                    Text(referenceItem.command)
                        .font(.system(size: 11.5, design: .monospaced))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: copiedCommand == referenceItem.command ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                    if copiedCommand == referenceItem.command {
                        Text(L10n.text("reference.copied"))
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                }
                if let detail = referenceItem.detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(pal.ink.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(pal.ink.opacity(0.84))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(pal.ink.opacity(0.075))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.format("reference.copy_help", referenceItem.command))
    }

    private var gutter: some View {
        Rectangle()
            .fill(pal.dash.opacity(0.24))
            .frame(width: DeckGeom.gutterWidth)
            .overlay {
                Text(card.title.uppercased())
                    .font(Ink.tabFont)
                    .tracking(Ink.tabTracking)
                    .lineLimit(1)
                    .foregroundStyle(pal.ink.opacity(0.72))
                    .frame(width: DeckGeom.editorHeight - 44)
                    .rotationEffect(.degrees(onRight ? 90 : -90))
            }
            .clipped()
            .overlay(alignment: onRight ? .trailing : .leading) {
                EdgeLine()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(pal.ink.opacity(0.22))
                    .frame(width: 1)
            }
    }

    private func copy(_ command: String) {
        guard ReferenceCatalog.copy(command) else { return }
        clearCopiedWork?.cancel()
        withAnimation(.easeOut(duration: 0.12)) { copiedCommand = command }
        let work = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.12)) { copiedCommand = nil }
        }
        clearCopiedWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}
