import SwiftUI

struct ABPlaybackView: View {
    @ObservedObject var viewModel: ABAudioAnnotationViewModel
    let adUnitID: String
    private let abButtonAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    var body: some View {
        VStack(spacing: 20) {
            // Invisible spacer to preserve layout above controls
            Text("Filename spacer")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(0)

            playbackControls
                .padding(.top, 4)

            Spacer(minLength: 16)

            abSwitch

            if !viewModel.currentFileName.isEmpty {
                Text(viewModel.currentFileName)
                    .font(.headline)
                    .foregroundColor(viewModel.hideCurrentFileName ? .white : .black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .animation(abButtonAnimation, value: viewModel.hideCurrentFileName)
            }

            Button(viewModel.hideCurrentFileName ? "Show" : "Hide") {
                withAnimation(abButtonAnimation) {
                    viewModel.toggleFilenameVisibility()
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)

            Spacer(minLength: 0)

            Divider()

            BannerAdView(adUnitID: adUnitID)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.vertical, 4)
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 20) {
            // Playback controls
            HStack(spacing: 15) {
                Button(action: { viewModel.goToBeginning() }) {
                    Image(systemName: "backward.end.fill")
                }

                Button(action: { viewModel.goBackward(by: 3) }) {
                    ZStack {
                        Image(systemName: "gobackward")
                        Text("3")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .offset(x: 0.3, y: 1)
                    }
                }

                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }

                Button(action: { viewModel.goForward(by: 15) }) {
                    ZStack {
                        Image(systemName: "goforward")
                        Text("15")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .offset(x: 0, y: 1)
                    }
                }
            }
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            // Current playback time display
            HStack(spacing: 12) {
                Text(timeString(from: viewModel.currentTime))
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundColor(.primary)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 2)

                        Rectangle()
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: geometry.size.width * viewModel.progress, height: 2)

                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 2, height: 12)
                            .offset(x: geometry.size.width * viewModel.progress - 1)
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
                .frame(height: 12)

                Text(timeString(from: viewModel.duration))
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, -10)
        }
    }

    private var abSwitch: some View {
        Button {
            viewModel.toggleActiveSlot()
        } label: {
            Text("ab")
                .font(.custom("LeagueSpartan-Bold", size: 34))
                .foregroundColor(viewModel.activeSlot?.isInvertedAppearance == true ? .white : .black)
                .frame(width: 140, height: 140)
                .background(
                    Circle()
                        .fill(viewModel.activeSlot?.isInvertedAppearance == true ? Color.black : Color.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
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
