import AVFoundation

/// 离线语音播报：TTS 渲染后**离线烘焙**现场 PA 效果（短延迟回声 + 球场混响），
/// 模拟裁判透过场内广播报分的空间感；运行时用 AVAudioPlayer 播放成品，
/// 无实时引擎、无路由竞争崩溃。音频自动路由到已连接的蓝牙耳机。
///
/// - **只报最新**：连续得分 debounce 合并，只播报最后一条。
/// - **单一裁判人声**：整场只用「所选语言 + 所选性别」这一把嗓子，中途切换即时生效。
/// - **文案缓存 + 预取**：同一文案只烘焙一次；`prefetch` 让下一分可能出现的文案
///   提前烘好，真正点击时缓存命中、即点即播。
/// - **渲染串行**：系统 TTS 同时只服务一条渲染，预取与实时播报排同一条队，
///   相同文案共享同一个进行中的任务。
/// - MainActor 串行化状态访问。
@MainActor
final class Announcer {

    private var pendingWork: DispatchWorkItem?
    private var playTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var cache: [String: Data] = [:]

    /// 进行中的渲染（按 key 去重）与串行链尾。
    private var inFlight: [String: Task<Data?, Never>] = [:]
    private var renderChain: Task<Void, Never>?

    /// 合并快速连点的间隔。渲染在点击瞬间就开始，这段只推迟「播放」，
    /// 用来避免连点时第一条刚出声就被掐断的碎音。
    private let debounceDelay: TimeInterval = 0.10

    var language: AnnounceLanguage = .chinese
    var umpire: UmpireVoice = .female

    /// 裁判声源。`.bundled` = 用随包的高质量预录片段（用户没装增强系统人声时）；
    /// `.system` = 系统 TTS。一场比赛内固定一种，避免出现两把嗓子。
    enum VoiceSource { case system, bundled }
    var source: VoiceSource = .system

    /// 一句待播内容：文本（系统 TTS 用）+ 可选的内置片段序列（有任一短句无片段则为 nil）。
    struct Utterance {
        var text: String
        var clipIDs: [String]? = nil
        var emphatic: Bool = false
    }

    // MARK: - 对外接口

    /// 朗读一句文案。连续调用只会播报最后一条。
    func speak(_ text: String, emphatic: Bool = false) {
        speak(Utterance(text: text, emphatic: emphatic))
    }

    func speak(_ utterance: Utterance) {
        guard let plan = makePlan(utterance) else { return }
        AudioSessionManager.shared.activate()

        pendingWork?.cancel()
        playTask?.cancel()
        player?.stop()   // 打断上一条（连点场景）

        // 立刻开始渲染（缓存命中则瞬间完成）；debounce 只推迟播放这一步。
        let render = Task<Data?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.audio(for: plan)
        }
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in self?.playWhenReady(render) }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: work)
    }

    /// 预先烘焙一句进缓存（不播放）。已缓存/正在渲染的直接跳过。
    func prefetch(_ text: String, emphatic: Bool = false) {
        prefetch(Utterance(text: text, emphatic: emphatic))
    }

    func prefetch(_ utterance: Utterance) {
        guard let plan = makePlan(utterance),
              cache[plan.key] == nil, inFlight[plan.key] == nil else { return }
        Task { [weak self] in _ = await self?.audio(for: plan) }
    }

    /// 立即停止并清空待播（撤销、新比赛清场，不发声）。进行中的渲染继续跑完进缓存。
    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        playTask?.cancel()
        player?.stop()
    }

    // MARK: - 渲染与播放

    /// 一次渲染所需的全部输入（文案 + 人声/片段 + 缓存键）。
    private struct Plan {
        let text: String
        let emphatic: Bool
        let voice: AVSpeechSynthesisVoice?
        let cjkVoice: AVSpeechSynthesisVoice?
        /// 非 nil = 用内置片段渲染（失败再退回系统 TTS）
        let clips: (ids: [String], language: AnnounceLanguage, umpire: UmpireVoice)?
        let key: String
    }

    private func makePlan(_ u: Utterance) -> Plan? {
        let trimmed = u.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let voice = matchVoice()
        // 英文播报里若出现中文（队名），队名那几个字用中文嗓念出，其余保持英音
        let needsMix = language != .chinese && trimmed.containsCJKText
        let cjkVoice = needsMix ? Self.pickVoice(languageCode: "zh-CN", umpire: umpire) : nil
        let useClips = source == .bundled && u.clipIDs != nil
        let clips = useClips ? (ids: u.clipIDs!, language: language, umpire: umpire) : nil
        guard voice != nil || clips != nil else { return nil }
        let key = useClips
            ? "clips|\(VoiceClips.folder(language: language, umpire: umpire))|\(u.clipIDs!.joined(separator: ","))|\(u.emphatic)"
            : "tts|\(trimmed)|\(voice?.identifier ?? "-")|\(cjkVoice?.identifier ?? "-")|\(u.emphatic)"
        return Plan(text: trimmed, emphatic: u.emphatic, voice: voice, cjkVoice: cjkVoice, clips: clips, key: key)
    }
    /// 取成品音频：缓存命中直接返回；否则排进串行渲染链（同 key 复用进行中的任务）。
    private func audio(for plan: Plan) async -> Data? {
        if let cached = cache[plan.key] { return cached }
        if let running = inFlight[plan.key] { return await running.value }

        let previous = renderChain
        let task = Task<Data?, Never> { [weak self] in
            _ = await previous?.value   // 排队：等上一条渲染完，避免多条 TTS 同时抢引擎
            let data = await Self.bake(plan)
            guard let self else { return data }
            if let data {
                if self.cache.count > 60 { self.cache.removeAll() }   // 粗粒度限容
                self.cache[plan.key] = data
            }
            self.inFlight[plan.key] = nil
            return data
        }
        inFlight[plan.key] = task
        renderChain = Task { _ = await task.value }
        return await task.value
    }

    /// TTS 渲染 + 现场 PA 烘焙（纯后台工作，不碰 Announcer 状态）。
    nonisolated private static func bake(_ plan: Plan) async -> Data? {
        var buffer: AVAudioPCMBuffer?
        if let clips = plan.clips {
            buffer = await VoiceClips.renderAsync(clipIDs: clips.ids, language: clips.language, umpire: clips.umpire)
        }
        if buffer == nil, let voice = plan.voice {
            // 裁判喊话与报分同速：之前一刀切放慢反而让 quiet/let 拖沓、"Out" 也没更清楚。
            // 喊话的清晰度改由烘焙阶段「去回声」解决（回声才是糊掉短词的元凶）。
            let rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
            if let cjkVoice = plan.cjkVoice {
                buffer = await TTSRender.renderMixed(text: plan.text, primaryVoice: voice,
                                                     cjkVoice: cjkVoice, rate: rate, pitch: 1.0)
            } else {
                buffer = await TTSRender.render(text: plan.text, voice: voice, rate: rate, pitch: 1.0)
            }
        }
        guard let buffer else { return nil }
        // 用文案的稳定 hash 做背景起点偏移——不同比分的底噪从不同位置取，不再千篇一律
        let seed = plan.text.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        var data = await OfflineFX.bakeStadiumPAAsync(buffer, emphatic: plan.emphatic, seed: seed)
        if data == nil {   // 偶发失败：稍候重试一次
            try? await Task.sleep(nanoseconds: 250_000_000)
            data = await OfflineFX.bakeStadiumPAAsync(buffer, emphatic: plan.emphatic, seed: seed)
        }
        return data
    }

    /// debounce 到点：等渲染结果（通常已就绪）后播放；期间若被更新的一条取消则不播。
    private func playWhenReady(_ render: Task<Data?, Never>) {
        playTask = Task { [weak self] in
            guard let data = await render.value, let self, !Task.isCancelled else { return }
            self.player?.stop()
            self.player = try? AVAudioPlayer(data: data)
            self.player?.play()
        }
    }

    // MARK: - 人声挑选

    /// 整场唯一的裁判人声：完全跟随所选播报语言 + 性别，中途切换即时生效。
    /// 不按每句文本切换语言——那会造成「第三个声音」在场上出现。
    private func matchVoice() -> AVSpeechSynthesisVoice? {
        Self.pickVoice(languageCode: language.voiceCode, umpire: umpire)
    }

    /// 常见系统人声的姓名→性别对照（很多人声的 gender 字段是「未指定」，
    /// 只按字段过滤会漏掉真实存在的男/女声，导致切换无效）。
    nonisolated private static let maleNameHints = [
        "daniel", "arthur", "aaron", "fred", "gordon", "rishi", "alex",
        "oliver", "eddy", "reed", "rocko", "binbin", "禾"
    ]
    nonisolated private static let femaleNameHints = [
        "tingting", "婷", "yushu", "语舒", "yue", "meijia", "sinji", "shasha", "lili",
        "kate", "serena", "martha", "stephanie", "susan", "samantha", "karen",
        "moira", "tessa", "fiona", "ava", "allison", "nora", "zoe", "shelley",
        "sandy", "flo", "kathy", "grandma", "nicky", "vicki", "princess"
    ]

    /// 推断人声性别：优先 gender 字段，未指定则按姓名对照猜。
    nonisolated static func inferredGender(_ voice: AVSpeechSynthesisVoice) -> AVSpeechSynthesisVoiceGender {
        if voice.gender != .unspecified { return voice.gender }
        let n = voice.name.lowercased()
        if maleNameHints.contains(where: { n.contains($0) }) { return .male }
        if femaleNameHints.contains(where: { n.contains($0) }) { return .female }
        return .unspecified
    }

    /// 指定语言下所选性别的人声是否存在（用于界面提示）。
    nonisolated static func voiceAvailable(gender: UmpireVoice, languageCode: String) -> Bool {
        let prefix = String(languageCode.prefix(2))
        let wanted: AVSpeechSynthesisVoiceGender = gender == .female ? .female : .male
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(prefix) && inferredGender($0) == wanted
        }
    }

    /// 从系统人声中挑选：先按（推断）性别过滤（无匹配则退回全部），再取音质最高的。
    /// **完全确定性**：音质、区域匹配相同时用 identifier 兜底排序，
    /// 保证同一设置每次都挑到同一把嗓子（否则男声会时好时坏、忽男忽女）。
    nonisolated static func pickVoice(languageCode: String, umpire: UmpireVoice) -> AVSpeechSynthesisVoice? {
        let prefix = String(languageCode.prefix(2))
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == languageCode || $0.language.hasPrefix(prefix) }
        guard !all.isEmpty else { return AVSpeechSynthesisVoice(language: languageCode) }

        let wanted: AVSpeechSynthesisVoiceGender = umpire == .female ? .female : .male
        let genderMatched = all.filter { inferredGender($0) == wanted }
        let pool = genderMatched.isEmpty ? all : genderMatched

        func rank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
            switch q {
            case .premium: return 3
            case .enhanced: return 2
            default: return 1
            }
        }
        // 优先级：音质高 > 教程推荐的那把嗓子 > 精确区域匹配（zh-CN 优于 zh-TW）> identifier 稳定兜底。
        // 「推荐嗓子」与设置页安装教程一致：用户照教程装完，听到的就是教程里那一个。
        let preferred = recommendedVoiceName(languageCode: languageCode, umpire: umpire).lowercased()
        return pool.sorted { a, b in
            let ra = rank(a.quality), rb = rank(b.quality)
            if ra != rb { return ra > rb }
            let pa = a.name.lowercased().hasPrefix(preferred) ? 1 : 0
            let pb = b.name.lowercased().hasPrefix(preferred) ? 1 : 0
            if pa != pb { return pa > pb }
            let ea = a.language == languageCode ? 1 : 0
            let eb = b.language == languageCode ? 1 : 0
            if ea != eb { return ea > eb }
            return a.identifier < b.identifier
        }.first
    }

    /// 安装教程里推荐的人声名（英文名前缀，用于匹配 voice.name）。
    /// 2026-09 在 iOS 真机核实：zh-CN 有 Lili (Premium) 女 / Han (Premium) 男；
    /// en-GB 有 Kate (Enhanced) 女 / Jamie (Premium) 男（identifier 叫 Malcolm）。
    nonisolated static func recommendedVoiceName(languageCode: String, umpire: UmpireVoice) -> String {
        if languageCode.hasPrefix("zh") { return umpire == .female ? "lili" : "han" }
        return umpire == .female ? "kate" : "jamie"
    }

    /// 当前语言是否已安装 增强/高级 音质人声（用于提示用户下载更真实的人声）。
    nonisolated static func hasEnhancedVoice(for language: AnnounceLanguage) -> Bool {
        let prefix = String(language.voiceCode.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(prefix) && ($0.quality == .enhanced || $0.quality == .premium)
        }
    }
}
