import SwiftUI

enum CoachStyle {
    static let background = Color(red: 0.055, green: 0.064, blue: 0.071)
    static let surface = Color(red: 0.103, green: 0.117, blue: 0.126)
    static let accent = Color(red: 0.77, green: 0.97, blue: 0.39)
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.05)
    static let muted = Color(red: 0.68, green: 0.73, blue: 0.75)
    static let stroke = Color.white.opacity(0.10)
}

struct CoachCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(CoachStyle.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20).strokeBorder(CoachStyle.stroke)
                    .allowsHitTesting(false)
            }
    }
}

struct CoachActionStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(primary ? CoachStyle.ink : Color.primary)
            .background(primary ? CoachStyle.accent : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.48)
            .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension View {
    func coachCard() -> some View { modifier(CoachCard()) }

    func coachPage() -> some View {
        self.frame(maxWidth: 620)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
    }

    func coachBackground() -> some View {
        background(CoachStyle.background.ignoresSafeArea())
    }
}
