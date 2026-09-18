//
//  momentApp.swift
//  moment
//
//  Created by jody on 12/09/26.
//

import SwiftUI
import SwiftData

@main
struct momentApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: LineEntity.self)
        } catch {
            fatalError("could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            CanvasView(lineWidth: 1.5, lineEntity:
                        LineEntity(
                            id: UUID(),
                            encodedLines: nil))
        }
    }
}
