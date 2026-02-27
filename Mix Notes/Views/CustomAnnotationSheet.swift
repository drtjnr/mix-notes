import SwiftUI
import AVFoundation

struct CustomAnnotationSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var recorder = AudioRecorderManager()
    @State private var noteText = ""
    @State private var showMicPermissionAlert = false

    let timestamp: TimeInterval?
    let onAddText: (String) -> Void
    let onAddAudioRecording: (String?, URL) -> Void
    let onPausePlayback: () -> Void
    let onResumePlayback: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Enter note", text: $noteText)
                    .font(MixNotesDesign.sfFont(16))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top, 20)

                Divider()
                    .padding(.horizontal)

                VStack(spacing: 10) {
                    if recorder.isRecording {
                        Text(formattedDuration(recorder.recordingDuration))
                            .font(MixNotesDesign.sfFont(18, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.red)
                    } else {
                        Text("Or record a voice note")
                            .font(MixNotesDesign.sfFont(14))
                            .foregroundColor(MixNotesDesign.warmGray)
                    }

                    Button {
                        handleRecordTap()
                    } label: {
                        Circle()
                            .fill(recorder.isRecording ? Color.red.opacity(0.8) : Color.red)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Group {
                                    if recorder.isRecording {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(.white)
                                            .frame(width: 22, height: 22)
                                    } else {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 22, height: 22)
                                    }
                                }
                            )
                    }
                }

                Spacer()
            }
            .background(MixNotesDesign.cream)
            .navigationTitle("Custom Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.cancelRecording()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTextAnnotation()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .alert("Microphone Access Required", isPresented: $showMicPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record voice notes.")
        }
    }

    private func handleRecordTap() {
        if recorder.isRecording {
            // Stop recording → auto-add and close
            if let url = recorder.stopRecording() {
                let text = noteText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : noteText
                onAddAudioRecording(text, url)
                onResumePlayback()
                isPresented = false
            }
        } else {
            // Start recording → pause main playback first
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        onPausePlayback()
                        try? recorder.startRecording()
                    } else {
                        showMicPermissionAlert = true
                    }
                }
            }
        }
    }

    private func addTextAnnotation() {
        onAddText(noteText)
        isPresented = false
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "0:%02d.%d", seconds, tenths)
    }
}
