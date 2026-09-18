//
//  CanvasModel.swift
//  moment
//
//  Created by jody on 15/09/26.
/// this file includes all the canvas information

import Foundation
import Combine
import SwiftData
import SwiftUI

//MARK: - font extension
extension Font {
    static func memofont(size: CGFloat) -> Font {
        return Font.custom("memofont", size: size)
    }
    
    static func memofontBold(size: CGFloat) -> Font {
        return Font.custom("memofont-Bold", size: size)
    }
}

// MARK: - timed point
/// stores a point's position and when it was created relative to the beginning of the line
struct TimedPoint: Codable {
    var x: Double
    var y: Double
    var timeOffset: Double
    
    /// converts the stored x/y values back into a CGPoint for drawing
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    init(point: CGPoint, timeOffset: Double) {
        self.x = point.x
        self.y = point.y
        self.timeOffset = timeOffset
    }
}

// MARK: - line struct
/// in memory representation of a line
/// codable allows swift to translate my struct into a format that can be stored and then translate it back into the struct when i load it
struct Line: Identifiable, Codable {
    var id: UUID
    
    /// points together with the time each point was created
    var timedPoints: [TimedPoint] = []
    
    /// when the line started, relative to the start of the session
    var startOffset: Double = 0
    
    /// converts the timedPoints into regular CGPoints for drawing
    var points: [CGPoint] {
        timedPoints.map { $0.cgPoint }
    }
    
    init(
        id: UUID = UUID(),
        timedPoints: [TimedPoint] = [],
        startOffset: Double = 0
    ) {
        self.id = id
        self.timedPoints = timedPoints
        self.startOffset = startOffset
    }
    
    //MARK: Replay
    /// returns a copy of the line containing only points that should be visible at the given elapsed time.
    func trimmed(toElapsed elapsed: Double) -> Line {
        let visible = timedPoints.filter {
            $0.timeOffset <= elapsed
        }
        
        var copy = self
        copy.timedPoints = visible
        
        return copy
    }
}


// MARK: - line persistence model
/// marks as a swift data persistent model, therefore must use final class
/// defines what is stored in SwiftData
@Model
final class LineEntity {
    @Attribute(.unique) var id: UUID /// ensure the id is unique to the database
    var descriptionText: String /// the description text field for the user
    var createdAt: Date /// when the session starts
    
    var encodedLines: Data? /// JSON-encoded [Line] which keeps the actual strokes
    
    var characterLimit: Int = 50 /// character limit
    
    init(id: UUID,
         descriptionText: String = "" ,
         createdAt: Date = Date(),
         encodedLines: Data?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.descriptionText = String(descriptionText.prefix(50))
        self.encodedLines = encodedLines
    }
    
    /// formatting my date hehehehe
    var formattedDateString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: createdAt)
        }
    
    /// character limit -- didSet is like onChange but for backend (and you use it on Observable Object)
    /// compared to onchange it checks immediately
    /// this ensures that the description is limited to 50 characters
//    var description: String {
//        get {
//            descriptionText
//        } set {
//            if newValue.count > characterLimit {
//                descriptionText = String(newValue.prefix(characterLimit))
//            } else {
//                descriptionText = newValue
//            }
//        }
//    }
}

// MARK: - memo persistence model
/// this is different from the line persistent model because it represents one drawing/ memo
@Model
final class MemoEntity {
    var id: UUID
    var createdAt: Date
    var descriptionText: String
    var encodedLines: Data?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        descriptionText: String,
        encodedLines: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.descriptionText = descriptionText
        self.encodedLines = encodedLines
    }
}

// MARK: - Canvas View Model
final class CanvasModel: ObservableObject {
    /// current drawing state
    @Published var lines: [Line] = []
    @Published var currentLine: Line?
    
    /// replay state
    @Published var isReplaying = false
    @Published var replayLines: [Line] = []
    
    /// timing
    private var sessionStartTime: Date? // when drawing started
    private var currentLineStartTime: Date? // time of the current stroke to compute offsets
    private var replayTimer: Timer? // timer for replay
    
    //MARK: drawing
    func lineStarted(at point: CGPoint) {
         let now = Date()
        
        if sessionStartTime == nil {
            sessionStartTime = now
        }
        
        currentLineStartTime = now
        
        let startOffset = now.timeIntervalSince(sessionStartTime!)
        
        currentLine = Line(
            timedPoints: [
                TimedPoint(point: point, timeOffset: 0)
            ],
            startOffset: startOffset
        )
    }
    
    /// appends the new timed point, since the line changed
    func lineOnChange(to point: CGPoint) {
        /// start time of the movement (elapsed time)
        guard let start = currentLineStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        currentLine?.timedPoints.append(
            TimedPoint(point: point,
                       timeOffset: elapsed)
        )
    }
    
    /// if a stroke has more than one point, append to a finished line and return it
    @discardableResult
    func lineEnded() -> Line? {
        var finishedLine: Line?
        
        if let line = currentLine,
           line.timedPoints.count > 1 {
            lines.append(line)
            finishedLine = line
        }
        
        /// clear current stroke and its start time for the next
        currentLine = nil
        currentLineStartTime = nil
        
        return finishedLine
    }
    
    //MARK: clear
    func clear() {
        lines.removeAll()
        currentLine = nil
        sessionStartTime = nil
    }
    
    //MARK: load (on app restart)
    /// load lines from database and resets the session start time
    func loadLines(_ loaded: [Line]) {
        lines = loaded
        sessionStartTime = nil
        self.startReplay()
    }
    
    //MARK: replay
    func startReplay(speed: Double = 2.5) {
        /// make sure the canvas is empty before starting the replay
        guard !lines.isEmpty else { return }
        
        isReplaying = true
        replayLines = [] /// clear array
        
        let replayBegin = Date()
        let totalDuration = lines.map { line in
            /// max of start offset + the last points of offset
            line.startOffset + (line.timedPoints.last?.timeOffset ?? 0)
        } .max() ?? 0
        
        /// clear the existing timer that might still be running to prevent clashes
        replayTimer?.invalidate()
        
        /// starts a new timer with 60 fps that fires indefinitely
        /// timer.scheduled timer creates repeating timer and immediately schedules it on the current run loop
        replayTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true) {
                /// allows closure from strong retain cycle of repeating timer
                /// to deallocate self, so it can end if there's a collapse elsewhere
                /// otherwise, self keeps the timer's closure alive, and the closure keeps self alive
                /// so neither can ever be deallocated even if the view disappears
                [weak self] timer in
                
                /// weak makes this part optional, so to safely unwrap: if self still exists, it becomes strong and non-optional
                guard let self else { return }
                
                /// elapsed time since start * speed multiplier
                let elapsed = Date().timeIntervalSince(replayBegin) * speed
                
                self.replayLines = self.lines.compactMap { line in
                    
                    /// for each line it is replaying, calculate the duration that it has passed and returns a trimmed version of the stroke up to the elapsed time
                    /// if negative, stroke hasn't started and skips
                    let lineElapsed = elapsed - line.startOffset
                    guard lineElapsed >= 0 else {
                        return nil
                    }
                    
                    return line.trimmed(toElapsed: lineElapsed)
                }
                
                /// once the duration is up, it stops playing
                if elapsed >= totalDuration {
                    timer.invalidate()
                    
                    self.isReplaying = false
                    self.replayLines = self.lines
                }
            }
    }
    
    //MARK: stop replay
    func stopReplay() {
        replayTimer?.invalidate()
        
        isReplaying = false
        replayLines = []
    }
}

