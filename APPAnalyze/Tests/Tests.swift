//
//  Tests.swift
//  Tests
//
//  Created by hexiao on 2023/8/21.
//

import XCTest
import SwiftDemangle

final class Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let a = "s16pgHomePageModule06PGMainC16_5009021_SubCell33_C4CD798CB5F3BA52699FDA71B41D3DB3LLC18walletBenefitLabelSo7UILabelCvpfiAGyXEfU_".classDemangling()
        XCTAssert(a.contains("pgHomePageModule.(PGMainPage_5009021_SubCell in _C4CD798CB5F3BA52699FDA71B41D3DB3)"))
        //
        let b = "s20pgPingouDetailModule14ShareInfoModelV4DataCSgWObTm".classDemangling()
        XCTAssert(b == ["pgPingouDetailModule.ShareInfoModel.Data"])
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
