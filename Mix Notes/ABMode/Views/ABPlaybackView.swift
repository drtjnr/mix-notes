import SwiftUI

struct ABPlaybackView: View {
    @ObservedObject var viewModel: ABAudioAnnotationViewModel
    let adUnitID: String
    private let abButtonAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    var body: some View {
        VStack(spacing: 16) {
            playbackControls
                .padding(.top, 4)

            Spacer(minLength: 14)

            abSwitch

            if !viewModel.currentFileName.isEmpty {
                Text(viewModel.currentFileName)
                    .font(MixNotesDesign.sfFont(16, weight: .medium))
                    .foregroundColor(viewModel.hideCurrentFileName ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .animation(abButtonAnimation, value: viewModel.hideCurrentFileName)
            }

            Button {
                withAnimation(abButtonAnimation) {
                    viewModel.toggleFilenameVisibility()
                }
            } label: {
                Text(viewModel.hideCurrentFileName ? "Show" : "Hide")
                    .font(MixNotesDesign.sfFont(15))
                    .foregroundColor(MixNotesDesign.charcoal)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(MixNotesDesign.cream)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(MixNotesDesign.charcoal.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Spacer(minLength: 0)

            Rectangle()
                .fill(MixNotesDesign.lightTaupe)
                .frame(height: 1)

            BannerAdView(adUnitID: adUnitID)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.vertical, 4)
        }
        .background(MixNotesDesign.cream)
    }

    private var playbackControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Spacer()

                // Skip back — lightweight outline
                Button(action: { viewModel.goToBeginning() }) {
                    Image(systemName: "backward.end")
                        .font(.system(size: 22, weight: .light))
                }
                .frame(width: 48, height: 48)

                Spacer()

                // Rewind 3s
                Button(action: { viewModel.goBackward(by: 3) }) {
                    ZStack {
                        Image(systemName: "gobackward")
                            .font(.system(size: 32, weight: .light))
                        Text("3")
                            .font(.system(size: 13, weight: .bold))
                            .offset(x: 0.3, y: 1)
                    }
                }
                .frame(width: 56, height: 56)

                Spacer()

                // Play/Pause
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .offset(x: viewModel.isPlaying ? 0 : 2)
                }
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .stroke(MixNotesDesign.charcoal, lineWidth: 2)
                )

                Spacer()

                // Forward 15s
                Button(action: { viewModel.goForward(by: 15) }) {
                    ZStack {
                        Image(systemName: "goforward")
                            .font(.system(size: 32, weight: .light))
                        Text("15")
                            .font(.system(size: 13, weight: .bold))
                            .offset(x: 0, y: 1)
                    }
                }
                .frame(width: 56, height: 56)

                Spacer()

                // Repeat
                Button(action: { viewModel.toggleRepeat() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 22))
                        .foregroundColor(viewModel.isRepeating ? MixNotesDesign.charcoal : MixNotesDesign.warmGray)
                }
                .frame(width: 48, height: 48)

                Spacer()
            }
            .foregroundColor(MixNotesDesign.charcoal)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)

            HStack(spacing: 12) {
                Text(timeString(from: viewModel.currentTime))
                    .font(MixNotesDesign.sfFont(14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.darkTaupe)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(MixNotesDesign.lightTaupe)
                            .frame(height: 4)

                        // Filled portion
                        Capsule()
                            .fill(MixNotesDesign.mediumTaupe)
                            .frame(width: geometry.size.width * viewModel.progress, height: 4)

                        // Thumb
                        Circle()
                            .fill(MixNotesDesign.charcoal)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            .offset(x: geometry.size.width * viewModel.progress - 7)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                viewModel.currentTime = progress * viewModel.duration
                                viewModel.progress = progress
                            }
                            .onEnded { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                viewModel.seek(to: progress)
                            }
                    )
                }
                .frame(height: 20)

                Text(timeString(from: viewModel.duration))
                    .font(MixNotesDesign.sfFont(14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.darkTaupe)
            }
            .padding(.horizontal, 24)
            .padding(.top, -8)
        }
    }

    private var abSwitch: some View {
        Button {
            viewModel.toggleActiveSlot()
        } label: {
            Text("ab")
                .font(.custom("LeagueSpartan-Bold", size: 32))
                .foregroundColor(viewModel.activeSlot?.isInvertedAppearance == true ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                .frame(width: 130, height: 130)
                .background(
                    Circle()
                        .fill(viewModel.activeSlot?.isInvertedAppearance == true ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                )
                .overlay(
                    Circle()
                        .stroke(MixNotesDesign.charcoal, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasLoadedAudio)
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let time = abs(timeInterval)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let sign = timeInterval < 0 ? "-" : ""
        return String(format: "%@%02d:%02d", sign, minutes, seconds)
    }
}
