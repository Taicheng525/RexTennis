import SwiftUI

/// 三大满贯场地主题：温网（草地）/ 法网（红土）/ 美网（硬地）。
enum CourtTheme: String, CaseIterable, Codable, Identifiable {
    case wimbledon
    case rolandGarros
    case usOpen

    var id: String { rawValue }

    func title(zh: Bool) -> String {
        switch self {
        case .wimbledon: return zh ? "温网" : "Wimbledon"
        case .rolandGarros: return zh ? "法网" : "Roland-Garros"
        case .usOpen: return zh ? "美网" : "US Open"
        }
    }

    /// 主题副标题（营造赛事氛围的小字）。
    var subtitle: String {
        switch self {
        case .wimbledon: return "THE CHAMPIONSHIPS"
        case .rolandGarros: return "TERRE BATTUE · PARIS"
        case .usOpen: return "FLUSHING MEADOWS · NY"
        }
    }

    // MARK: - 场地配色

    /// 场地主色（背景渐变上端）。
    var court: Color {
        switch self {
        case .wimbledon: return Color(red: 0.18, green: 0.42, blue: 0.24)   // 草地绿
        case .rolandGarros: return Color(red: 0.78, green: 0.38, blue: 0.23) // 红土
        case .usOpen: return Color(red: 0.13, green: 0.38, blue: 0.66)      // 硬地蓝
        }
    }

    /// 场地深色（背景渐变下端）。
    var courtDeep: Color {
        switch self {
        case .wimbledon: return Color(red: 0.07, green: 0.20, blue: 0.11)
        case .rolandGarros: return Color(red: 0.47, green: 0.20, blue: 0.11)
        case .usOpen: return Color(red: 0.05, green: 0.17, blue: 0.34)
        }
    }

    /// 场地线 / 主文字色（奶白）。
    var line: Color { Color(red: 0.97, green: 0.95, blue: 0.89) }

    /// 我方按钮主色。
    var homeAccent: Color {
        switch self {
        case .wimbledon: return Color(red: 0.33, green: 0.19, blue: 0.56)   // 温网紫
        case .rolandGarros: return Color(red: 0.09, green: 0.36, blue: 0.26) // 法网深绿
        case .usOpen: return Color(red: 0.95, green: 0.78, blue: 0.28)      // 美网黄
        }
    }

    /// 我方按钮文字色。
    var onHome: Color {
        self == .usOpen ? Color(red: 0.06, green: 0.15, blue: 0.30) : line
    }

    /// 对方按钮：统一奶白（网球白），文字用场地深色。
    var awayAccent: Color { line }
    var onAway: Color { courtDeep }

    /// 强调色（发球标记、平分/金球徽章、选中态）。
    var badge: Color { Color(red: 0.87, green: 0.92, blue: 0.34) }          // 网球黄绿
}

// MARK: - 球场线背景

/// 竖向网球场线条（半场示意），叠加在场地渐变上，低透明度。
struct CourtLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let court = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.10)

        // 外框（双打线）
        p.addRect(court)

        // 单打边线
        let singles = court.width * 0.13
        p.move(to: CGPoint(x: court.minX + singles, y: court.minY))
        p.addLine(to: CGPoint(x: court.minX + singles, y: court.maxY))
        p.move(to: CGPoint(x: court.maxX - singles, y: court.minY))
        p.addLine(to: CGPoint(x: court.maxX - singles, y: court.maxY))

        // 球网（中线）
        let netY = court.midY
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: netY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: netY))

        // 发球线（上下各一条，位于网与底线之间）
        let serviceOffset = court.height * 0.22
        for y in [netY - serviceOffset, netY + serviceOffset] {
            p.move(to: CGPoint(x: court.minX + singles, y: y))
            p.addLine(to: CGPoint(x: court.maxX - singles, y: y))
        }

        // 中央发球线（两条发球线之间）
        p.move(to: CGPoint(x: court.midX, y: netY - serviceOffset))
        p.addLine(to: CGPoint(x: court.midX, y: netY + serviceOffset))

        // 底线中点标记
        let tick = court.height * 0.015
        p.move(to: CGPoint(x: court.midX, y: court.minY))
        p.addLine(to: CGPoint(x: court.midX, y: court.minY + tick))
        p.move(to: CGPoint(x: court.midX, y: court.maxY))
        p.addLine(to: CGPoint(x: court.midX, y: court.maxY - tick))

        return p
    }
}

/// 主题背景：场地渐变 + 低透明度球场线。
struct CourtBackground: View {
    let theme: CourtTheme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.court, theme.courtDeep],
                           startPoint: .top, endPoint: .bottom)
            CourtLines()
                .stroke(theme.line.opacity(0.13), lineWidth: 1.5)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 通用样式

extension View {
    /// 主题卡片：半透明深色底 + 场地线描边。
    func themedCard(_ theme: CourtTheme, cornerRadius: CGFloat = 18) -> some View {
        self
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(red: 0.97, green: 0.95, blue: 0.89).opacity(0.18), lineWidth: 1)
            )
    }
}

/// 迷你网球（发球方指示）。
struct TennisBall: View {
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(Color(red: 0.85, green: 0.91, blue: 0.32))
            .overlay(
                Circle().stroke(Color.white.opacity(0.7), lineWidth: size * 0.07)
                    .scaleEffect(0.62)
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }
}
