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

                HStack {
                    Slider(value: $settings.thickness, in: AppSettings.thicknessRange, step: 1) {
                        Text("Thickness")
                    }
                    Text("\(Int(settings.thickness)) pt")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }

                Text("The line is shown on screen while this window is open, so you can try sizes out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Durations") {
                minutesStepper("Tomato", value: $settings.focusMinutes)
                minutesStepper("Short break", value: $settings.shortBreakMinutes)
                minutesStepper("Long break", value: $settings.longBreakMinutes)
                Stepper(value: $settings.longBreakEvery, in: 2...12) {
                    LabeledContent("Long break every", value: "\(settings.longBreakEvery) tomatoes")
                }
            }

            Section("When a session ends") {
                Picker("When a session ends", selection: $settings.endMode) {
                    ForEach(EndMode.allCases) { mode in
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
            }

            Section("Menu bar") {
                Toggle("Show time remaining", isOn: $settings.showTimeInMenuBar)
                Text("Hold ⌥ Option in the menu to pause instead of stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minutesStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...120) {
            LabeledContent(title, value: "\(value.wrappedValue) min")
        }
    }
}
