import SwiftUI

/// The website's drafting-paper palette, with native Dynamic Type and dark appearances.
enum ArrivalTheme {
    static let paper = Color("ArrivalPaper")
    static let panel = Color("ArrivalPanel")
    static let ink = Color("ArrivalInk")
    static let muted = Color("ArrivalMuted")
    static let signal = Color("ArrivalSignal")
    static let signalInk = Color("ArrivalSignalInk")
    static let rule = ink.opacity(0.16)

    static func heading(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif).weight(.regular)
    }

    static func label(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .monospaced)
    }
}

struct ArrivalPaper: View {
    var body: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: CGFloat.zero, through: size.width, by: 24) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: 24) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(ArrivalTheme.ink.opacity(0.035)), lineWidth: 0.5)
        }
        .background(ArrivalTheme.paper)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ArrivalSectionHeading: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(number).foregroundStyle(ArrivalTheme.signalInk)
            Text(title).foregroundStyle(ArrivalTheme.muted)
            Rectangle().fill(ArrivalTheme.rule).frame(height: 1)
                .accessibilityHidden(true)
        }
        .font(ArrivalTheme.label())
        .textCase(.uppercase)
        .tracking(1)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

struct ArrivalActionStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .foregroundStyle(primary ? ArrivalTheme.paper : ArrivalTheme.ink)
            .background(primary ? ArrivalTheme.ink : ArrivalTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(primary ? .clear : ArrivalTheme.rule, lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ArrivalFieldHeader: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 58

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("EXEA LABS")
                Spacer()
                Text("FIELD CAPTURE")
            }
            .font(ArrivalTheme.label())
            .tracking(1.5)
            .foregroundStyle(ArrivalTheme.muted)

            HStack(alignment: .firstTextBaseline) {
                Text("Arrival")
                    .font(.system(size: titleSize, weight: .light, design: .serif))
                    .tracking(-2)
                Text("/ 01")
                    .font(ArrivalTheme.label(.footnote))
                    .foregroundStyle(ArrivalTheme.signalInk)
            }
            .foregroundStyle(ArrivalTheme.ink)

            Text("Scan a room once.")
                .font(ArrivalTheme.heading(.title2))
                .foregroundStyle(ArrivalTheme.ink)
            Text("Capture its walls, fixtures and details for a digital twin.")
                .font(.subheadline)
                .foregroundStyle(ArrivalTheme.muted)
            Rectangle().fill(ArrivalTheme.rule).frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
    }
}
