import SwiftUI
import UniformTypeIdentifiers

public struct RadialWheelView: View {
    public let items: [RadialItem]
    public let hoveredIndex: Int?
    public let onSelect: (RadialItem) -> Void

    private let innerRadius: CGFloat = 45
    private let outerRadius: CGFloat = 135

    public init(
        items: [RadialItem],
        hoveredIndex: Int?,
        onSelect: @escaping (RadialItem) -> Void
    ) {
        self.items = items
        self.hoveredIndex = hoveredIndex
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            // Background shadow / glow
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: outerRadius * 2 + 10, height: outerRadius * 2 + 10)
                .blur(radius: 8)

            // Slices
            ForEach(0..<items.count, id: \.self) { index in
                sliceView(index: index)
            }

            // Center hole with icon / hint
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(nsColor: .windowBackgroundColor).opacity(0.9), Color.black.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                        Text("Tangerine")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
        }
        .frame(width: outerRadius * 2 + 20, height: outerRadius * 2 + 20)
    }

    @ViewBuilder
    private func sliceView(index: Int) -> some View {
        let count = max(items.count, 1)
        let sliceAngle = 360.0 / Double(count)
        let startAngle = Angle(degrees: Double(index) * sliceAngle - 90.0)
        let endAngle = Angle(degrees: Double(index + 1) * sliceAngle - 90.0)
        let midAngle = Angle(degrees: (startAngle.degrees + endAngle.degrees) / 2.0)
        let isHovered = (hoveredIndex == index)

        ZStack {
            // Slice wedge shape
            RadialSectorShape(
                startAngle: startAngle,
                endAngle: endAngle,
                innerRadius: innerRadius,
                outerRadius: isHovered ? outerRadius + 8 : outerRadius
            )
            .fill(
                isHovered
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.95), Color.orange.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(nsColor: .darkGray).opacity(0.7), Color.black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RadialSectorShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRadius,
                    outerRadius: isHovered ? outerRadius + 8 : outerRadius
                )
                .stroke(isHovered ? Color.white.opacity(0.8) : Color.white.opacity(0.12), lineWidth: isHovered ? 2 : 1)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

            // Content (Icon + Label)
            let iconPos = pointOnCircle(
                angle: midAngle,
                radius: (innerRadius + outerRadius) / 2.0 + (isHovered ? 4 : 0)
            )

            VStack(spacing: 3) {
                Image(systemName: items[index].iconName)
                    .font(.system(size: isHovered ? 20 : 18, weight: .bold))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.9))

                Text(items[index].title)
                    .font(.system(size: isHovered ? 12 : 11, weight: .bold, design: .rounded))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.85))
            }
            .position(x: iconPos.x + outerRadius + 10, y: iconPos.y + outerRadius + 10)
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

// Custom Shape for ring sector
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
