import SwiftUI

/// 全局调色板：简约高级 dark 风，草地绿 + 网球黄绿 + 奶白，无花哨背景。
enum RexTheme {
    /// 背景（近黑，带一点暖绿底色）。
    static let bgTop = Color(red: 0.055, green: 0.070, blue: 0.058)
    static let bgBottom = Color(red: 0.016, green: 0.020, blue: 0.016)

    /// 卡片与描边。
    static let card = Color.white.opacity(0.055)
    static let hairline = Color.white.opacity(0.10)

    /// 文字（暖奶白）。
    static let text = Color(red: 0.96, green: 0.95, blue: 0.90)
    static let textDim = text.opacity(0.55)
    static let textFaint = text.opacity(0.35)

    /// 网球黄绿（比分、强调）。
    static let accent = Color(red: 0.84, green: 0.90, blue: 0.34)

    /// 深草绿（我方按钮 / 主行动）。
    static let green = Color(red: 0.13, green: 0.42, blue: 0.26)

    /// 网球白（对方按钮）。
    static let cream = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let onCream = Color(red: 0.07, green: 0.09, blue: 0.07)
}

/// App 背景：近黑渐变 + 顶部一抹极淡的草绿光晕，干净不抢戏。
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [RexTheme.bgTop, RexTheme.bgBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [RexTheme.green.opacity(0.22), .clear],
                           center: .init(x: 0.5, y: -0.15),
                           startRadius: 10, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 通用样式

extension View {
    /// 深色卡片：半透明白底 + 发丝描边。
    func rexCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(RexTheme.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(RexTheme.hairline, lineWidth: 1)
            )
    }
}

/// 拟物迷你网球（发球方指示 / 标题装饰）：立体渐变 + 白色接缝线。
struct TennisBall: View {
    var size: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Color(red: 0.93, green: 0.97, blue: 0.45),
                                            Color(red: 0.68, green: 0.76, blue: 0.20)],
                                   center: .init(x: 0.35, y: 0.30),
                                   startRadius: size * 0.05, endRadius: size * 0.85)
                )
            // 接缝：左右两段圆弧
            SeamArc()
                .stroke(Color.white.opacity(0.85), lineWidth: max(size * 0.07, 0.8))
                .padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: size * 0.12, y: size * 0.10)
    }
}

/// 网球接缝曲线（两条相对的弧）。
private struct SeamArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.30, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.30, y: rect.maxY),
                       control: CGPoint(x: rect.minX + w * 0.72, y: rect.midY))
        p.move(to: CGPoint(x: rect.maxX - w * 0.30, y: rect.minY + h * 0.04))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - w * 0.30, y: rect.maxY - h * 0.04),
                       control: CGPoint(x: rect.minX + w * 0.28, y: rect.midY))
        return p
    }
}
