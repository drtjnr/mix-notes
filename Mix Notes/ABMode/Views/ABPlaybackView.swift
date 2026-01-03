import SwiftUI

struct ABPlaybackView: View {
    @ObservedObject var viewModel: ABAudioAnnotationViewModel
    let adUnitID: String
    private let abButtonAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    var body: some View {
        VStack(spacing: 16) {
            // Invisible spacer to preserve layout above controls
            Text("Filename spacer")
                .font(MixNotesDesign.sfFont(17, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(0)

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
            GeometryReader { geometry in
                HStack(spacing: 34) {
                    Button(action: { viewModel.goToBeginning() }) {
                        Image(systemName: "backward.end.fill")
                    }

                    Button(action: { viewModel.goBackward(by: 3) }) {
                        ZStack {
                            Image(systemName: "gobackward")
                            Text("3")
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: 0.3, y: 1)
                        }
                    }

                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(MixNotesDesign.charcoal.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .scaleEffect(1.15)

                    Button(action: { viewModel.goForward(by: 15) }) {
                        ZStack {
                            Image(systemName: "goforward")
                            Text("15")
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: 0, y: 1)
                        }
                    }

                    Button(action: { viewModel.toggleRepeat() }) {
                        Image(systemName: "repeat")
                            .foregroundColor(viewModel.isRepeating ? MixNotesDesign.charcoal : MixNotesDesign.warmGray)
                    }
                }
                .foregroundColor(MixNotesDesign.charcoal)
                .frame(width: geometry.size.width * 0.8)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 34)
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            HStack(spacing: 10) {
                Text(timeString(from: viewModel.currentTime))
                    .font(MixNotesDesign.sfFont(16))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.charcoal)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(MixNotesDesign.lightTaupe)
                            .frame(height: 1)

                        Rectangle()
                            .fill(MixNotesDesign.mediumTaupe)
                            .frame(width: geometry.size.width * viewModel.progress, height: 1)

                        Circle()
                            .fill(MixNotesDesign.charcoal)
                            .frame(width: 8, height: 8)
                            .offset(x: geometry.size.width * viewModel.progress - 4)
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
                .frame(height: 10)

                Text(timeString(from: viewModel.duration))
                    .font(MixNotesDesign.sfFont(16))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.warmGray)
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
