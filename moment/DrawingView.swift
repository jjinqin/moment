//
//  DrawingPath.swift
//  moment
//
//  Created by jody on 12/09/26.
//

import SwiftUI

/// model of the line
struct Line: Codable {
    var points: [CGPoint]
}

struct DrawingView: View {
    
    /// hold all the information about the lines that we are going to draw
    /// i only need the points by the lines so i stored it as a CG point
    @State private var lines = [Line]()
    
    /// to store the deleted lines somewhere so i can call it again using redo
    @State private var deletedLines = [Line]()
    
    var body: some View {
        VStack {
            
            HStack {
                
                /// undo button
                Button {
                    guard !lines.isEmpty else { return }
                    let last = lines.removeLast()
                    deletedLines.append(last)
                } label: {
                    /// to replace with own assets afterwards
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(lines.count == 0)
                .opacity(lines.isEmpty ? 0 : 1)
                
                /// redo button
                Button {
                    let last = deletedLines.removeLast() /// breakpoint because .removeLast() on an empty array triggered a precondition failure
                    lines.append(last)
                    
                } label: {
                    /// to replace with my own assets afterwards
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(deletedLines.count == 0)
                .opacity(deletedLines.count == 0 ? 0 : 1)
                
                //TO DO: add settings button
            }
            
            Canvas { context, size in
                
                /// for each of my lines that i want to draw
                for line in lines {
                    /// create a path for each line and i want it to be able to change (variable)
                    /// can give an array of CG points to this specific path
                    var path = Path()
                    path.addLines(line.points)
                    
                    /// now there's a path that i can tell the context to draw (i.e. stroke)
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
            /// this is so that when we move across the canvas, we can draw the path
            .gesture(
                DragGesture(minimumDistance: 0)
                /// want to see where the line is in between, the moment there is a drag gesture
                    .onChanged { value in
                        /// let my new point be the location of where the value is
                        /// translation is the difference between the starting point and the ending point
                        /// so, if both add up to be 0, it means that we're looking at the starting point
                        /// ensure that when we start a new point, there are no "deletedlines" where we can redo on top of our new line
                        let newPoint = value.location
                        if value.translation.width + value.translation.height == 0 {
                            deletedLines.removeAll()
                            lines.append(Line(points: [newPoint]))
                        }
                        /// else, the translation should be > 0, and that will be a new line that we're looking at
                        /// index is always -1 because we start from 0
                        /// for the new line, append the new point to the new line's points' array
                        else {
                            let index = lines.count - 1
                            lines[index].points.append(newPoint)
                        }
                    }
                /// because during the drag gesture, we create a new line when the drag begins and then append points as the drag continues
                /// in some cases, a drag that starts and end without moving enough to add points, we might end up with a line that has no points
                    .onEnded { value in
                        /// if let 'last' = ... performs optional binding because if lines.last?.points is non-nil, it binds the [CGPoint] to the local constant last
                        /// lines.last gets the last Line in my lines array, but it's optional because the array might be empty
                        /// access the points array on the last Line, if it exists but if the line is empty, the whole expression evaluates to nil
                        /// remove the line
                        if let last = lines.last?.points, last.isEmpty {
                            lines.removeLast()
                        }
                    }
            )
        }
    }
}

#Preview {
    DrawingView()
}
