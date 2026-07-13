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

/// 拟物迷你网球（发球方指示 / 标题装饰）：立体渐变球体 + 上下两条白色接缝弧。
struct TennisBall: View {
    var size: CGFloat = 12

    var body: some View {
        ZStack {
            // 球体：径向渐变（左上高光 → 边缘压深）
            Circle()
                .fill(
                    RadialGradient(colors: [Color(red: 0.91, green: 0.96, blue: 0.46),
                                            Color(red: 0.74, green: 0.83, blue: 0.26),
                                            Color(red: 0.55, green: 0.64, blue: 0.17)],
                                   center: .init(x: 0.34, y: 0.30),
                                   startRadius: size * 0.02, endRadius: size * 0.95)
                )
            // 边缘暗角，增强球体感
            Circle()
                .fill(
                    RadialGradient(colors: [.clear, .black.opacity(0.28)],
                                   center: .center,
                                   startRadius: size * 0.30, endRadius: size * 0.52)
                )
            // 接缝：靠近上极、下极各一条外凸的白弧
            TennisSeam()
                .stroke(Color.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: max(size * 0.08, 0.9), lineCap: .round))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: size * 0.10, y: size * 0.08)
    }
}

/// 网球接缝：上极与下极各一条外凸的弧，形成经典网球「双弯」外观。
private struct TennisSeam: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + w * x, y: rect.minY + h * y)
        }
        var p = Path()
        // 上弧（凸向顶部）
        p.move(to: pt(0.13, 0.35))
        p.addQuadCurve(to: pt(0.87, 0.35), control: pt(0.5, 0.00))
        // 下弧（凸向底部）
        p.move(to: pt(0.13, 0.65))
        p.addQuadCurve(to: pt(0.87, 0.65), control: pt(0.5, 1.00))
        return p
    }
}
