//
//  ContentView.swift
//  moment
//
//  Created by jody on 12/09/26.
//

import SwiftUI



struct ContentView: View {
    
    @State private var isButtonHidden = true
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            if isButtonHidden {
                Button {
                    isButtonHidden = false
                } label: {
                    Image(systemName: "globe")
                }
            }
            
            Button("bring button back") {
                isButtonHidden = true
            }
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
