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

/// 写实拟物网球（发球方指示 / 标题装饰）：立体渐变球体 + 镜面高光 + 凹陷接缝 + 边缘暗角。
struct TennisBall: View {
    var size: CGFloat = 12

    var body: some View {
        ZStack {
            // ① 球体：多档径向渐变（左上受光亮、右下背光暗）
            Circle().fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.89, green: 0.97, blue: 0.44),
                        Color(red: 0.77, green: 0.88, blue: 0.27),
                        Color(red: 0.56, green: 0.69, blue: 0.16),
                        Color(red: 0.39, green: 0.49, blue: 0.11)
                    ],
                    center: UnitPoint(x: 0.36, y: 0.30),
                    startRadius: 0, endRadius: size * 0.78
                )
            )

            // ② 边缘暗角，强化球体积
            Circle().fill(
                RadialGradient(
                    colors: [.clear, .clear, .black.opacity(0.32)],
                    center: .center, startRadius: size * 0.28, endRadius: size * 0.52
                )
            )

            // ③ 接缝凹槽（暗、略下移、微模糊）——制造凹陷立体感
            TennisSeam()
                .stroke(.black.opacity(0.22),
                        style: StrokeStyle(lineWidth: max(size * 0.11, 1), lineCap: .round))
                .offset(y: size * 0.012)
                .blur(radius: max(size * 0.015, 0.5))

            // ④ 接缝白线
            TennisSeam()
                .stroke(.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: max(size * 0.075, 0.8), lineCap: .round))

            // ⑤ 镜面高光光斑（左上）
            Ellipse()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.65), .white.opacity(0.0)],
                                   center: .center, startRadius: 0, endRadius: size * 0.20)
                )
                .frame(width: size * 0.38, height: size * 0.26)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.15, y: -size * 0.20)

            // ⑥ 轮廓细描边（绒毛边缘）
            Circle().strokeBorder(.black.opacity(0.10), lineWidth: max(size * 0.012, 0.4))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.42), radius: size * 0.06, y: size * 0.05)
    }
}

/// 网球接缝：从顶到底的 S 形波浪曲线，把球面分成两片水滴——真实网球正面外观。
private struct TennisSeam: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + w * x, y: rect.minY + h * y)
        }
        var path = Path()
        // 两段在中点平滑衔接（切线同向）→ 标准 S
        path.move(to: pt(0.50, 0.05))
        path.addQuadCurve(to: pt(0.50, 0.50), control: pt(0.06, 0.27))   // 上半：左凸
        path.addQuadCurve(to: pt(0.50, 0.95), control: pt(0.94, 0.73))   // 下半：右凸
        return path
    }
}
