//
//  QSCloudKitSynchronizerOperation.swift
//  Pods
//
//  Created by Manuel Entrena on 18/05/2018.
//

import Foundation

public class CloudKitSynchronizerOperation: Operation {
    override public var isAsynchronous: Bool { return true }
    override public var isExecuting: Bool { return state == .executing }
    override public var isFinished: Bool { return state == .finished }
    @objc public var errorHandler: ((CloudKitSynchronizerOperation, Error) -> ())?
    
    var state = State.ready {
        willSet {
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
        }
        didSet {
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }
    
    enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { return "is" + self.rawValue }
    }
    
    override public func start() {
        if self.isCancelled {
            state = .finished
        } else {
            state = .ready
            main()
        }
    }
    
    override public func main() {
        state = self.isCancelled ? .finished : .executing
    }
    
    public func finish(error: Error?) {
        if let error = error {
            errorHandler?(self, error)
        }
        state = .finished
    }
}
