//
//  ContentView.swift
//  moment
//
//  Created by jody on 12/09/26.
// for experiments

import SwiftUI
import SwiftData
import Foundation
import Combine

struct ContentView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            /// background color
            Color.white
            
            //MARK: top area
            HStack(alignment: .top) {
                Image("memo logo")
                    .resizable()
                    .frame(width: 125, height: 90)
                    .allowsHitTesting(false)
                    .padding(.horizontal, 10)
                    .padding(.top, -22)
//                    .background(Color.green)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 16) {
                    
                    //MARK: dismiss pop-up
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image("xmark")
                            .resizable()
                            .frame(width: 45, height: 45)
                    }
                    
                    Button {
                        // action
                    } label: {
                        HStack {
                            Text("new memo")
                                .font(.memofont(size: 28))
                                .foregroundStyle(.black)
                            Image("new memo")
                                .resizable()
                                .frame(width: 45, height: 45)
                        }
                    }
                    
                    Button {
                        // action
                    } label: {
                        HStack {
                            Text("calendar")
                                .font(.memofont(size: 28))
                                .foregroundStyle(.black)
                            Image("calendar")
                                .resizable()
                                .frame(width: 45, height: 45)
                        }
                    }
                }
                .padding(.top, 65)
                .padding(.horizontal, 20)
                .padding(.bottom, -80)
                .ignoresSafeArea(edges: .all)
//                .background(Color.red)
            }
            
            //MARK: bottom area
            ZStack(alignment: .bottomLeading) {
                Color.clear
                
                Text("""
                me overwhelmed when me write
                me draw, me capture feelings, moments --
                stickies, sketchbook, screen.
                me moments all over the place.
                me lost, so me use MEMO.
                me find MEMOries.
                """)
                .font(.memofont(size: 28))
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
