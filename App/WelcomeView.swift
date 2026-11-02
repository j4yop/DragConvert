import SwiftUI

struct WelcomeView: View {
    private let warm = LinearGradient(
        colors: [Color(red: 0.98, green: 0.78, blue: 0.55),
                 Color(red: 0.90, green: 0.45, blue: 0.28)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 40) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 168, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .frame(width: 240)

            VStack(alignment: .leading, spacing: 18) {
                Text("Convert files mid-drag")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Drag any file in Finder, then hold a key. The wheel appears and stays put. Move out to a wedge and release.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    row(keys: ["⇧"], title: "Convert", detail: "JPG · PNG · PDF · TXT …")
                    row(keys: ["⌥", "⌘"], title: "Tools", detail: "Crop · Compress · Redact …")
                    row(keys: ["⌃"], title: "Actions", detail: "AirDrop · Move · Copy Path …")
                }
                .padding(.top, 4)

                HStack(spacing: 12) {
                    Button("Got it") { NSApp.keyWindow?.close() }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.18))

                    Text("Everything runs on this Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: 400, alignment: .leading)
        }
        .padding(.horizontal, 44)
        .frame(width: 760, height: 430)
        .background(warm)
    }

    private func row(keys: [String], title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(minWidth: 26, minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.7)))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 62, alignment: .leading)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 70, alignment: .leading)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
