import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class RadialWheelViewModel: ObservableObject {
    @Published public var items: [RadialItem]
    @Published public var hoveredIndex: Int?
    public var onSelect: ((RadialItem) -> Void)?

    public init(
        items: [RadialItem] = [],
        hoveredIndex: Int? = nil,
        onSelect: ((RadialItem) -> Void)? = nil
    ) {
        self.items = items
        self.hoveredIndex = hoveredIndex
        self.onSelect = onSelect
    }
}

public struct RadialWheelView: View {
    @ObservedObject public var viewModel: RadialWheelViewModel

    private let innerRadius: CGFloat = 46
    private let outerRadius: CGFloat = 132
    private let sectorGapDegrees: Double = 2.0

    public init(viewModel: RadialWheelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Ambient soft background glow & blur
            Circle()
                .fill(Color.black.opacity(0.60))
                .frame(width: outerRadius * 2 + 16, height: outerRadius * 2 + 16)
                .blur(radius: 12)

            // Minimalist background disc with hairline border
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.45))
                .frame(width: outerRadius * 2 + 4, height: outerRadius * 2 + 4)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            // Radial Slices
            ForEach(0..<viewModel.items.count, id: \.self) { index in
                sliceView(index: index)
            }

            // Minimalist Center Hub
            centerHubView
        }
        .frame(width: outerRadius * 2 + 24, height: outerRadius * 2 + 24)
    }

    // MARK: - Center Hub View
    private var centerHubView: some View {
        let isHovering = (viewModel.hoveredIndex != nil && viewModel.hoveredIndex! < viewModel.items.count)
        let hoveredItem = isHovering ? viewModel.items[viewModel.hoveredIndex!] : nil

        return ZStack {
            // Center background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.14, blue: 0.17).opacity(0.95),
                            Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .overlay(
                    Circle()
                        .stroke(
                            isHovering ? Color.orange.opacity(0.5) : Color.white.opacity(0.12),
                            lineWidth: isHovering ? 1.5 : 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)

            // Content inside center hub
            if let item = hoveredItem {
                VStack(spacing: 2) {
                    Image(systemName: item.iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)
                        .transition(.scale.combined(with: .opacity))

                    Text(item.title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    Text("DROP")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.0)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: viewModel.hoveredIndex)
    }

    // MARK: - Slice View
    @ViewBuilder
    private func sliceView(index: Int) -> some View {
        let count = max(viewModel.items.count, 1)
        let fullSliceAngle = 360.0 / Double(count)
        let halfGap = sectorGapDegrees / 2.0

        let startAngle = Angle(degrees: Double(index) * fullSliceAngle + halfGap - 90.0)
        let endAngle = Angle(degrees: Double(index + 1) * fullSliceAngle - halfGap - 90.0)
        let midAngle = Angle(degrees: (Double(index) + 0.5) * fullSliceAngle - 90.0)
        let isHovered = (viewModel.hoveredIndex == index)

        let targetOuter = isHovered ? outerRadius + 6 : outerRadius

        ZStack {
            // Sector Shape
            RadialSectorShape(
                startAngle: startAngle,
                endAngle: endAngle,
                innerRadius: innerRadius + 2,
                outerRadius: targetOuter
            )
            .fill(
                isHovered
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.46, blue: 0.12),
                                Color(red: 0.94, green: 0.32, blue: 0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(
                        Color.white.opacity(0.065)
                    )
            )
            .overlay(
                RadialSectorShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRadius + 2,
                    outerRadius: targetOuter
                )
                .stroke(
                    isHovered ? Color.white.opacity(0.65) : Color.white.opacity(0.08),
                    lineWidth: isHovered ? 1.5 : 0.8
                )
            )
            .shadow(
                color: isHovered ? Color.orange.opacity(0.40) : Color.clear,
                radius: 8,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)

            // Content (Icon + Title)
            let iconRadius = (innerRadius + outerRadius) / 2.0 + (isHovered ? 3 : 0)
            let iconPos = pointOnCircle(angle: midAngle, radius: iconRadius)

            VStack(spacing: 2) {
                Image(systemName: viewModel.items[index].iconName)
                    .font(.system(size: isHovered ? 18 : 16, weight: isHovered ? .bold : .medium))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.90))

                Text(viewModel.items[index].title)
                    .font(.system(size: isHovered ? 11 : 10, weight: isHovered ? .bold : .medium, design: .rounded))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.80))
            }
            .position(x: iconPos.x + outerRadius + 12, y: iconPos.y + outerRadius + 12)
        }
    }

    private func pointOnCircle(angle: Angle, radius: CGFloat) -> CGPoint {
        let radians = CGFloat(angle.radians)
        return CGPoint(
            x: radius * cos(radians),
            y: radius * sin(radians)
        )
    }
}

// Custom Shape for ring sector with gap
public struct RadialSectorShape: Shape {
    public var startAngle: Angle
    public var endAngle: Angle
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat

    public var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(outerRadius, innerRadius) }
        set {
            outerRadius = newValue.first
            innerRadius = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        // Outer arc
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Line to inner arc
        let innerEnd = CGPoint(
            x: center.x + innerRadius * cos(CGFloat(endAngle.radians)),
            y: center.y + innerRadius * sin(CGFloat(endAngle.radians))
        )
        path.addLine(to: innerEnd)

        // Inner arc (in reverse)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}
