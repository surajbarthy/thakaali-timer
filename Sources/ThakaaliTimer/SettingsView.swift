import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Line") {
                Picker("Position", selection: $settings.edge) {
                    ForEach(LineEdge.allCases) { edge in
                        Text(edge.label).tag(edge)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Style", selection: $settings.lineStyle) {
                    ForEach(LineStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Reverse direction", isOn: $settings.reverseDirection)
                Toggle("Pulse in the last minute", isOn: $settings.pulseNearEnd)

                HStack {
                    Slider(value: $settings.thickness, in: AppSettings.thicknessRange, step: 1) {
                        Text("Thickness")
                    }
                    Text("\(Int(settings.thickness)) pt")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }

                Text("Thickness is the resting size. The line doubles when a session starts or when you rest the pointer on it. It's shown while this window is open so you can try options out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Durations") {
                numberField("Tomato", value: $settings.focusMinutes, range: 1...120, unit: "min")
                numberField("Short break", value: $settings.shortBreakMinutes, range: 1...120, unit: "min")
                numberField("Long break", value: $settings.longBreakMinutes, range: 1...120, unit: "min")
                numberField("Long break every", value: $settings.longBreakEvery, range: 2...12, unit: "tomatoes")
            }

            Section("When a session ends") {
                Picker("When a session ends", selection: $settings.endStyle) {
                    ForEach(EndStyle.allCases) { mode in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                            Text(mode.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Toggle("Play a sound", isOn: $settings.playSound)
            }

            Section("Menu bar") {
                Toggle("Show countdown in menu bar", isOn: $settings.showTimeInMenuBar)
                Text("Hold ⌥ Option in the menu to pause instead of stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A typeable number with a stepper beside it, like System Settings. Values are kept in range.
    private func numberField(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        return LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: clamped, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
                Stepper(title, value: clamped, in: range)
                    .labelsHidden()
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .leading)
            }
        }
    }
}
