#!/usr/bin/env python3
"""
生成内置裁判人声片段 → Resources/Voices/<zh|en>_<female|male>/<clipID>.m4a

用法：
  1. 导出清单：
     TEST_RUNNER_REX_MANIFEST_OUT=$PWD/tools/manifest.json xcodebuild -project RexTennis.xcodeproj -scheme RexTennis \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:RexTennisTests/VoiceClipManifestTests
  2. 生成音频（任选一家）：
     OPENAI_API_KEY=xxx  python3 tools/gen_voices.py --provider openai
     ELEVEN_API_KEY=xxx  python3 tools/gen_voices.py --provider eleven
     AZURE_TTS_KEY=xxx AZURE_TTS_REGION=eastasia python3 tools/gen_voices.py --provider azure
     python3 tools/gen_voices.py --provider say        # macOS 自带 say，仅用于本地测试流程，音质不用于上架

  已存在的文件默认跳过（--force 重做）。输出统一转成 AAC 48kbps 单声道 m4a（afconvert）。
"""
import argparse, json, os, subprocess, sys, tempfile, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "manifest.json")
OUT_ROOT = os.path.join(ROOT, "Resources", "Voices")

# 每个 语言×性别 用哪把嗓子。ElevenLabs 填 voice_id；Azure 填 voice name；say 填 macOS 声音名。
VOICES = {
    "eleven": {   # 需要按你的账号里可用的 voice_id 填；下面是公共库里常见的英式声音示例
        ("en", "female"): os.environ.get("ELEVEN_EN_FEMALE", ""),
        ("en", "male"):   os.environ.get("ELEVEN_EN_MALE", ""),
        ("zh", "female"): os.environ.get("ELEVEN_ZH_FEMALE", ""),
        ("zh", "male"):   os.environ.get("ELEVEN_ZH_MALE", ""),
    },
    "openai": {   # gpt-4o-mini-tts，靠 instructions 控制口音/语气
        ("en", "female"): "coral",
        ("en", "male"):   "onyx",
        ("zh", "female"): "coral",
        ("zh", "male"):   "onyx",
    },
    "azure": {
        ("en", "female"): "en-GB-SoniaNeural",
        ("en", "male"):   "en-GB-RyanNeural",
        ("zh", "female"): "zh-CN-XiaoxiaoNeural",
        ("zh", "male"):   "zh-CN-YunxiNeural",
    },
    "say": {
        ("en", "female"): "Daniel",     # macOS 没有免费的英式女声，占位用 Daniel
        ("en", "male"):   "Daniel",
        ("zh", "female"): "Tingting",
        ("zh", "male"):   "Tingting",
    },
}

def to_m4a(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    # 先统一成 wav 再 afconvert，避免 afconvert 不认 mp3
    wav = dst + ".tmp.wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", "44100",
                    "-af", "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,apad=pad_dur=0.05",
                    wav], check=True)
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "48000", wav, dst], check=True)
    os.remove(wav)

def synth_say(text, voice, out_path):
    aiff = out_path + ".aiff"
    subprocess.run(["say", "-v", voice, "-r", "175", "-o", aiff, text], check=True)
    to_m4a(aiff, out_path); os.remove(aiff)

def synth_eleven(text, voice_id, lang, out_path):
    key = os.environ["ELEVEN_API_KEY"]
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128",
        data=json.dumps({"text": text, "model_id": "eleven_multilingual_v2",
                         "voice_settings": {"stability": 0.6, "similarity_boost": 0.8, "style": 0.15}}).encode(),
        headers={"xi-api-key": key, "Content-Type": "application/json"})
    mp3 = out_path + ".mp3"
    with urllib.request.urlopen(req, timeout=60) as r, open(mp3, "wb") as f:
        f.write(r.read())
    to_m4a(mp3, out_path); os.remove(mp3)

OPENAI_INSTRUCTIONS = {
    "en": ("You are a professional tennis chair umpire at Wimbledon. Speak in a clear, calm, authoritative "
           "British English (Received Pronunciation) accent. Announce crisply, no extra words."),
    "zh": ("你是一名专业的网球主裁判，用标准、清晰、沉稳的普通话播报比分。语气专业克制，不要加任何多余的词。"),
}

def synth_openai(text, voice, lang, out_path):
    key = os.environ["OPENAI_API_KEY"]
    req = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=json.dumps({"model": "gpt-4o-mini-tts", "voice": voice, "input": text,
                         "instructions": OPENAI_INSTRUCTIONS[lang], "response_format": "wav",
                         "speed": 0.96}).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    wav = out_path + ".wav"
    with urllib.request.urlopen(req, timeout=60) as r, open(wav, "wb") as f:
        f.write(r.read())
    to_m4a(wav, out_path); os.remove(wav)

def synth_azure(text, voice, lang, out_path):
    key, region = os.environ["AZURE_TTS_KEY"], os.environ.get("AZURE_TTS_REGION", "eastasia")
    xml_lang = "zh-CN" if lang == "zh" else "en-GB"
    ssml = (f'<speak version="1.0" xml:lang="{xml_lang}"><voice name="{voice}">'
            f'<prosody rate="-4%">{text}</prosody></voice></speak>')
    req = urllib.request.Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"),
        headers={"Ocp-Apim-Subscription-Key": key, "Content-Type": "application/ssml+xml",
                 "X-Microsoft-OutputFormat": "riff-44100hz-16bit-mono-pcm", "User-Agent": "RexTennis"})
    wav = out_path + ".wav"
    with urllib.request.urlopen(req, timeout=60) as r, open(wav, "wb") as f:
        f.write(r.read())
    to_m4a(wav, out_path); os.remove(wav)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--provider", choices=["openai", "eleven", "azure", "say"], required=True)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", help="只生成某个 语言_性别，如 zh_female")
    args = ap.parse_args()

    rows = json.load(open(MANIFEST, encoding="utf-8"))
    voices = VOICES[args.provider]
    total = done = 0
    for (lang, gender), voice in voices.items():
        folder = f"{lang}_{gender}"
        if args.only and args.only != folder: continue
        if not voice:
            print(f"[skip] {folder}: 未配置 voice"); continue
        for row in rows:
            total += 1
            out = os.path.join(OUT_ROOT, folder, row["id"] + ".m4a")
            if os.path.exists(out) and not args.force: continue
            os.makedirs(os.path.dirname(out), exist_ok=True)
            text = row[lang]
            try:
                if args.provider == "say":      synth_say(text, voice, out)
                elif args.provider == "eleven": synth_eleven(text, voice, lang, out)
                elif args.provider == "openai": synth_openai(text, voice, lang, out)
                else:                           synth_azure(text, voice, lang, out)
                done += 1
                print(f"[ok] {folder}/{row['id']}  {text}")
                if args.provider != "say": time.sleep(0.15)   # 温和一点，别触发限流
            except Exception as e:
                print(f"[fail] {folder}/{row['id']}: {e}", file=sys.stderr)
    print(f"完成：新生成 {done} / 共 {total}")

if __name__ == "__main__":
    main()
