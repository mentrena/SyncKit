//
//  CloudKitSynchronizerOperationTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 07/06/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

import Foundation
import XCTest
@testable import SyncKit

class CloudKitSynchronizerOperationTests: XCTestCase {
    
    var operation: CloudKitSynchronizerOperation!
    
    override func setUp() {
        super.setUp()
        
        operation = CloudKitSynchronizerOperation()
    }
    
    override func tearDown() {
        
        operation = nil
        super.tearDown()
    }
    
    func testStart_setsIsExecuting() {
        
        operation.start()
        
        XCTAssertTrue(operation.isExecuting)
        XCTAssertFalse(operation.isFinished)
    }
    
    func testStart_isCancelled_setsIsFinished() {
        
        operation.cancel()
        operation.start()
        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.isExecuting)
    }
    
    func testMain_setsIsExecuting() {
        
        operation.main()
        
        XCTAssertTrue(operation.isExecuting)
        XCTAssertFalse(operation.isFinished)
    }
    
    func testMain_isCancelled_setsIsFinished() {
        
        operation.cancel()
        operation.main()
        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.isExecuting)
    }
    
    func testFinish_setsIsFinished() {
        
        operation.finish(error: nil)
        
        XCTAssertTrue(operation.isFinished)
    }
    
    func testFinish_withError_callsErrorHandler() {
        
        let expectation = self.expectation(description: "handler called")
        var finishError: Error?
        
        operation.errorHandler = { operation, error in
            finishError = error
            expectation.fulfill()
        }
        
        operation.finish(error: NSError(domain: "test", code: 1, userInfo: nil))
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(operation.isFinished)
        let cocoaError = finishError as NSError?
        XCTAssertTrue(cocoaError?.domain == "test")
    }
}
