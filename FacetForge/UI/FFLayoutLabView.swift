import SwiftUI

/// Renders the production shell at a chosen width so XCUITest can exercise
/// widths the simulator window cannot be resized to by hand. This is a test
/// surface, launched only with `-FFLayoutLab`; the shipping app never shows
/// it, and the shell it renders is the same `FFAppShell`.
struct FFLayoutLabView: View {
    @State private var width: CGFloat = 640

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FFSpace.xxs) {
                Text("Layout lab")
                    .font(FFType.section)
                    .foregroundStyle(FFPalette.textPrimary.color)
                    .accessibilityIdentifier("layoutLab.title")

                Spacer(minLength: FFSpace.xs)

                ForEach(FFShellMetrics.testWidths, id: \.self) { candidate in
                    FFChip(
                        title: "\(Int(candidate))",
                        isSelected: width == candidate,
                        accessibilityIdentifier: "layout.width.\(Int(candidate))"
                    ) {
                        width = candidate
                    }
                }
            }
            .padding(.horizontal, FFSpace.sm)
            .frame(minHeight: 56)
            .background(FFPalette.panel.color)

            Rectangle()
                .fill(FFPalette.separator.color)
                .frame(height: 1)

            GeometryReader { proxy in
                FFAppShell(fixedWidth: width)
                    .frame(width: width, height: proxy.size.height)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .clipped()
            }
        }
        .background(FFPalette.canvas.color)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("layoutLab.root")
    }
}
