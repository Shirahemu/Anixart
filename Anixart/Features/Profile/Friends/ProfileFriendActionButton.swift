import SwiftUI

struct ProfileFriendActionButton: View {
    let state: ProfileFriendActionState
    var isBlocked = false
    var isRequestsDisallowed = false
    var isWorking = false
    let onSend: () -> Void
    let onRemove: () -> Void
    let onHide: () -> Void

    var body: some View {
        Group {
            if isBlocked {
                Label("Недоступно", systemImage: "lock")
                    .frame(maxWidth: .infinity)
            } else {
                content
            }
        }
        .font(.subheadline.weight(.semibold))
        .disabled(isWorking || isBlocked || (isRequestsDisallowed && state == .none))
        .overlay {
            if isWorking {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .none:
            Button {
                onSend()
            } label: {
                Label(isRequestsDisallowed ? "Заявки закрыты" : "Добавить", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .friends:
            Menu {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Удалить из друзей", systemImage: "person.badge.minus")
                }
            } label: {
                Label("В друзьях", systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .requestSent:
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Отменить", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .requestIncoming:
            HStack(spacing: 8) {
                Button {
                    onSend()
                } label: {
                    Label("Принять", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onHide()
                } label: {
                    Label("Скрыть", systemImage: "eye.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        case .unknown:
            Label("Статус неизвестен", systemImage: "questionmark.circle")
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
        }
    }
}
