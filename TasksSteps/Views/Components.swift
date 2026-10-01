import SwiftUI

/// 全局配色 / 尺寸常量
enum Theme {
    static let accent = Color(red: 0.30, green: 0.55, blue: 1.00)
    static let track = Color(.systemGray5)
    static let doneGreen = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let warnOrange = Color(red: 1.00, green: 0.58, blue: 0.00)

    /// 按进度取色：0% 灰蓝 → 100% 绿
    static func progressColor(_ p: Double) -> Color {
        if p >= 1 { return doneGreen }
        if p >= 0.6 { return accent }
        if p > 0 { return accent.opacity(0.85) }
        return Color(.systemGray3)
    }
}

// MARK: - 大号进度条（详情页用）

struct BigProgressBar: View {
    var progress: Double
    var height: CGFloat = 16
    /// 节点数量（用于在进度条上画分段刻度）
    var segments: Int = 0
    var animated: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Theme.track)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.progressColor(clamped).opacity(0.75),
                                     Theme.progressColor(clamped)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, geo.size.width * clamped))
                    .animation(animated ? .spring(response: 0.45, dampingFraction: 0.8) : nil,
                               value: clamped)

                // 分段刻度：每完成一个节点，进度条就跨过一格
                if segments > 1 {
                    HStack(spacing: 0) {
                        ForEach(1..<segments, id: \.self) { _ in
                            Rectangle()
                                .fill(Color(.systemBackground).opacity(0.55))
                                .frame(width: 1.5)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.leading, geo.size.width / CGFloat(segments))
                    .opacity(clamped > 0 ? 1 : 0)
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - 细进度条（列表页用）

struct MiniProgressBar: View {
    var progress: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.progressColor(progress))
                    .frame(width: max(0, geo.size.width * min(max(progress, 0), 1)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 圆形进度环

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 52
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Theme.progressColor(progress),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
            Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                .font(.system(size: size * 0.26, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 节点勾选圈

struct NodeCheck: View {
    var done: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(done ? Theme.doneGreen : Color(.systemGray3), lineWidth: 2)
                .frame(width: 24, height: 24)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.doneGreen))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
    }
}
