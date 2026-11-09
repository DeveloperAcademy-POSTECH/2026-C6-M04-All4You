//
//  AppLaunchView.swift
//  All4You
//
//  Created by 채유성 on 11/10/26.
//
//

import SwiftUI
import SwiftData

struct AppLaunchView: View {
    @State private var isShowingSplash = true
    @State private var isLogoDimmed = false
    
    var body: some View {
        ZStack {
            if isShowingSplash {
                splash
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .statusBarHidden(isShowingSplash)
        .task {
            guard isShowingSplash else { return }
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            withAnimation(.easeOut(duration: 0.25)) {
                isShowingSplash = false
            }
        }
    }
    
    private var splash: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                Image("FIRELINE")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(270, proxy.size.width * 0.72))
                    .opacity(isLogoDimmed ? 0.45 : 1)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isLogoDimmed
                    )
                    .onAppear {
                        isLogoDimmed = true
                    }
                    .accessibilityLabel("FIRELINE")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("FIRELINE 스플래시") {
    AppLaunchView()
        .modelContainer(for: FireCase.self, inMemory: true)
}
