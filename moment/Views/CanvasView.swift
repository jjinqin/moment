//
//  CanvasView.swift
//  moment
//
//  Created by jody on 12/09/26.
//

import SwiftUI
import Combine
import SwiftData

struct CanvasView: View {
    
    var lineWidth: Double = 1.5
    @StateObject private var canvasModel = CanvasModel()
    
    /// access to swiftdata
    @Environment(\.modelContext) private var modelContext
    
    /// stores all the lines together & helps you to find the data
    @Query private var storedLineEntities: [LineEntity]
    /// allows you to edit the data
    @Bindable var lineEntity: LineEntity
    /// ensure the keyboard slides away after it reaches 50 characters
    @FocusState private var isInputFocused: Bool
    
    /// for undo / redo
    @State private var deletedLines = [Line]()
    
    /// for showing the full screen pop-up
    @State private var showSheet: Bool = false
    
    /// ran into font problems
    //  init() {
    //        for family in UIFont.familyNames.sorted() {
    //            print("Family:", family)
    //            print("Fonts:", UIFont.fontNames(forFamilyName: family))
    //        }
    //    }
    
    
    var body: some View {
        VStack {
            
            HStack {
                Image("memo logo")
                    .resizable()
                    .frame(width: 125, height: 90)
                    .allowsHitTesting(false)
                    .padding(.horizontal, -10)
                
                Spacer()
                
                // MARK: - undo
                Button {
                    guard !canvasModel.lines.isEmpty else { return }
                    let last = canvasModel.lines.removeLast()
                    deletedLines.append(last)
                    
                    saveAllLinesToDB()
                    
                } label: {
                    /// to replace with own assets afterwards
                    Image("undo")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(7.05))
                }
                .disabled(canvasModel.lines.count == 0)
                .opacity(canvasModel.lines.isEmpty ? 0 : 1)
                
                // MARK: - redo
                Button {
                    guard !deletedLines.isEmpty else { return }
                    let last = deletedLines.removeLast() /// breakpoint because .removeLast() on an empty array triggered a precondition failure
                    canvasModel.lines.append(last)
                    
                    saveAllLinesToDB()
                    
                } label: {
                    /// to replace with my own assets afterwards
                    Image("undo")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .scaleEffect(x: -1, y: 1)
                        .rotationEffect(.degrees(-7.05))
                    
                }
                .disabled(deletedLines.count == 0)
                .opacity(deletedLines.count == 0 ? 0 : 1)
                
                //MARK: - settings
                Button {
                    showSheet.toggle()
                } label: {
                    Image("settings")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                /// should not try to include a sheet when a full screen cover is included
                /// should also not put an if else statement within a sheet
                .fullScreenCover(isPresented: $showSheet) {
                    ContentView()
                }
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
            .padding(.bottom, -80)
            .ignoresSafeArea(edges: .all)
            //            .background(Color.red)
            
            //MARK: - canvas
            /// The drawing surface: we render all finished lines and the in-progress line
            Canvas { context, size in
                
                let linesToDraw = canvasModel.isReplaying ? canvasModel.replayLines : canvasModel.lines
                
                /// for each of my lines that i want to draw
                for line in linesToDraw {
                    drawLine(line, into: &context)
                }
                
                /// draw the line that is currently being created
                if let currentLine = canvasModel.currentLine, !canvasModel.isReplaying {
                    drawLine(
                        currentLine,
                        into: &context)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) /// make sure the canvas fills available space
            /// this is so that when we move across the canvas, we can draw the path
            .gesture(
                DragGesture(minimumDistance: 0)
                /// want to see where the line is in between, the moment there is a drag gesture
                    .onChanged { value in
                        /// don't allow drawing during replay
                        guard !canvasModel.isReplaying else {
                            print("Drawing disabled: currently replaying")
                            return
                        }
                        
                        /// first movement -> start line
                        if canvasModel.currentLine == nil {
                            /// new drawing invalidates redo history
                            deletedLines.removeAll()
                            canvasModel.lineStarted(at: value.location)
                            print("Started line at: \(value.location)")
                        } else {
                            /// continue current line
                            canvasModel.lineOnChange(to: value.location)
                            print("Added point: \(value.location)")
                        }
                    }
                    .onEnded { _ in
                        /// If we are replaying a drawing, don't accept touches for new strokes
                        guard !canvasModel.isReplaying else {
                            print("Ignoring end: currently replaying")
                            return
                        }
                        
                        /// Finish the current line: this should append the line to canvasModel.lines inside lineEnded()
                        if let finishedLine = canvasModel.lineEnded() {
                            print("Finished line with points: \(finishedLine.points.count)")
                            saveLineToDB(finishedLine)
                        } else {
                            /// If there were fewer than 2 points, nothing is drawn
                            print("No line finished (not enough points)")
                        }
                    }
            )
            .onAppear {
                /// Make sure replay mode isn't accidentally left on, which would block drawing
                if canvasModel.isReplaying {
                    print("Replay was on at appear; turning it off so drawing works")
                    canvasModel.isReplaying = false
                }
                loadLinesFromDatabase()
            }
            
            //MARK: - date and text description
            Text(lineEntity.formattedDateString)
                .frame(maxWidth: .infinity, alignment: .leading)
//                .tracking(2) /// adds more space between the letter
                .padding(.horizontal, 20)
                .font(.memofontBold(size: 50))
            
            TextField("MEMOries here",
                      text: $lineEntity.descriptionText,
//                        Binding(get: {
//                lineEntity.description
//            }, set: { newValue in
//                if lineEntity.descriptionText.count >= lineEntity.characterLimit {
//                    /// FORCE RE-RENDER to forcefully clear out the extra keystrokes on the next layout pass???
//                    DispatchQueue.main.async {
//                        isInputFocused = false
//                    }
//                }
//            }),
                      axis: .vertical)
            .onChange(of: lineEntity.descriptionText) { oldValue, newValue in
                /// forcefully cutting the word!
                if newValue.count > lineEntity.characterLimit {
                    lineEntity.descriptionText = String(newValue.prefix(50))
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.leading)
            .lineLimit(2...2)
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
            .font(.memofontBold(size: 30))
//            .background(Color.red)
            
//            Text("\(lineEntity.descriptionText.count)/50")
            
        }
    }
    
    //MARK: - functions
    
    //MARK: draw line
    private func drawLine( _ line: Line, into context: inout GraphicsContext) {
        /// We need at least two points to draw a visible stroke
        guard line.points.count > 1 else {
            return
        }
        
        /// create an empty path for each line that i draw, build the path
        /// line.points contains the points that make up the user's stroke, so now connect the points of the line
        var path = Path()
        path.addLines(line.points)
        
        /// now there's a path that i can tell the context to draw (i.e. stroke)
        context.stroke(path,
                       with: .color(.black),
                       style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                       )
        )
    }
    
    
    //MARK: save new line
    private func saveLineToDB(_ line: Line) {
        guard storedLineEntities.first != nil else {
            /// if there's no existing entity, create one
            let entity = LineEntity(
                id: UUID(),
                descriptionText: "MEMOries here",
                createdAt: Date(),
                encodedLines: try? JSONEncoder().encode(canvasModel.lines))
            
            modelContext.insert(entity)
            try? modelContext.save()
            
            return
        }
    }
    
    //MARK: save all lines
    private func saveAllLinesToDB() {
        guard let entity = storedLineEntities.first else {
            let newEntity = LineEntity(id: UUID(),
                                       encodedLines: try? JSONEncoder().encode(canvasModel.lines))
            
            modelContext.insert(newEntity)
            try? modelContext.save()
            
            return
        }
        
        entity.encodedLines = try? JSONEncoder().encode(canvasModel.lines)
        try? modelContext.save()
    }
    
    //MARK: load lines
    private func loadLinesFromDatabase() {
        guard let entity = storedLineEntities.first,
              let data = entity.encodedLines,
              let loadedLines = try? JSONDecoder().decode(
                [Line].self,
                from: data) else {
            return
        }
        
        canvasModel.loadLines(loadedLines)
    }
    
    //MARK: clear database
    private func clearLinesFromDatabase() {
        for entity in storedLineEntities {
            modelContext.delete(entity)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("save faield: \(error)")
        }
    }
    
    
}


#Preview {
    CanvasView(lineWidth: 1.5,
               lineEntity: LineEntity(
                id: UUID(),
                encodedLines: nil
               ))
}

