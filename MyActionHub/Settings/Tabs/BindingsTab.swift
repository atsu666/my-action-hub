import SwiftUI

struct BindingsTab: View {
    @ObservedObject private var store = ConfigStore.shared

    @State private var draftCopy = BindingDraft()
    @State private var editingMode: BindingEditor.Mode = .add
    @State private var isEditorPresented = false
    @State private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footerBar
        }
        .sheet(isPresented: $isEditorPresented) {
            BindingEditor(
                mode: editingMode,
                draft: $draftCopy,
                existingBindings: store.config.bindings,
                onSave: handleSave,
                onCancel: { isEditorPresented = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Bindings")
                .font(.title2.bold())
            Spacer()
            Text("\(store.config.bindings.count) 件")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.config.bindings.isEmpty {
            emptyState
        } else {
            bindingsList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Binding がまだ登録されていません")
                .font(.headline)
            Text("「+」ボタンから追加してください")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bindingsList: some View {
        List(selection: $selectedID) {
            ForEach($store.config.bindings) { $binding in
                BindingRow(binding: $binding, onEdit: { startEdit(binding) })
                    .tag(binding.id)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button(action: startAdd) {
                Image(systemName: "plus")
            }
            Button(action: deleteSelected) {
                Image(systemName: "minus")
            }
            .disabled(selectedID == nil)
            Spacer()
        }
        .padding(8)
    }

    // MARK: - Actions

    private func startAdd() {
        editingMode = .add
        draftCopy = BindingDraft()
        isEditorPresented = true
    }

    private func startEdit(_ binding: ActionBinding) {
        editingMode = .edit(originalID: binding.id)
        draftCopy = BindingDraft.from(binding)
        isEditorPresented = true
    }

    private func handleSave(_ binding: ActionBinding) {
        if let idx = store.config.bindings.firstIndex(where: { $0.id == binding.id }) {
            store.config.bindings[idx] = binding
        } else {
            store.config.bindings.append(binding)
        }
        isEditorPresented = false
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        store.config.bindings.removeAll { $0.id == id }
        selectedID = nil
    }
}

private struct BindingRow: View {
    @Binding var binding: ActionBinding
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: $binding.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(binding.trigger.displayName).font(.body)
                Text(binding.action.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
