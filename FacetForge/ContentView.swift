import SwiftUI

struct ContentView: View {
    @State private var showingGallery = false

    private let ink = Color(red: 0.078, green: 0.086, blue: 0.102)
    private let porcelain = Color(red: 0.957, green: 0.945, blue: 0.918)
    private let metal = Color(red: 0.784, green: 0.631, blue: 0.353)

    var body: some View {
        ZStack {
            ink
                .ignoresSafeArea()

            VStack(spacing: 18) {
                FacetMark()
                    .frame(width: 108, height: 108)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(AppIdentity.displayName)
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(porcelain)
                        .accessibilityIdentifier("launch.title")

                    Text(AppIdentity.tagline)
                        .font(.callout)
                        .foregroundStyle(porcelain.opacity(0.72))
                        .accessibilityIdentifier("launch.tagline")
                }

                Text(AppIdentity.phaseLabel)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(metal)
                    .padding(.top, 4)
                    .accessibilityIdentifier("launch.phase")

                Button {
                    showingGallery = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                        Text("Open component gallery")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(metal)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 16)
                    .background(
                        Color(red: 0.165, green: 0.180, blue: 0.208),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(metal.opacity(0.55), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open component gallery")
            }
            .padding(48)
        }
        .accessibilityElement(children: .contain)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingGallery) {
            ComponentGalleryView()
        }
    }
}

private struct FacetMark: View {
    private let metal = Color(red: 0.784, green: 0.631, blue: 0.353)
    private let graphite = Color(red: 0.165, green: 0.180, blue: 0.208)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Diamond()
                    .fill(graphite)
                Diamond()
                    .stroke(metal, lineWidth: 2)
                FacetLines()
                    .stroke(metal.opacity(0.7), lineWidth: 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.36))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.36))
        path.closeSubpath()
        return path
    }
}

private struct FacetLines: Shape {
    func path(in rect: CGRect) -> Path {
        let crown = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.36)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: crown.y))
        path.addLine(to: CGPoint(x: rect.maxX, y: crown.y))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: crown)
        path.move(to: crown)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
