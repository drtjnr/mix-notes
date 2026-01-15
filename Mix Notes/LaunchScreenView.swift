import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Text("mix notes")
                .font(.custom("LeagueSpartan-Bold", size: 25))
                .foregroundColor(MixNotesDesign.charcoal)
                .kerning(-0.3)
        }
    }
}
