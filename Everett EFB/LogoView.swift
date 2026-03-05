import SwiftUI

struct LogoView: View {
    var body: some View {
        Image("efbLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 80)
            .padding(.vertical, 10)
    }
}
