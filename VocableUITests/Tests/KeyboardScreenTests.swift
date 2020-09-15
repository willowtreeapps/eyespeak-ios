//
//  KeyboardScreenTests.swift
//  KeyboardScreenTests
//
//  Created by Kevin Stechler on 4/22/20.
//  Copyright © 2020 WillowTree. All rights reserved.
//

import XCTest

class KeyboardScreenTests: BaseTest {
    let testPhrase = "Tests Main."

    func testWhenTyping_ThenTextShownOnOutputLabel() {
        mainScreen.keyboardNavButton.tap()
        keyboardScreen.typeText(testPhrase)
       
        XCTAssert(keyboardScreen.keyboardTextView.staticTexts[testPhrase].exists, "Expected the text \(testPhrase) to be displayed")
    }
    
    func testBackspaceRemovesCharacter(){
        mainScreen.keyboardNavButton.tap()
        keyboardScreen.typeText(testPhrase)
        
        // Need to do this until we figure out why the indentifier is being added to the Y button
        keyboardScreen.backspaceButton.element(boundBy: 1).tap()
        XCTAssert(keyboardScreen.keyboardTextView.staticTexts["Test"].exists, "Expected the text Test to be displayed")
    }
    
    func testClearResetsInput(){
        mainScreen.keyboardNavButton.tap()
        keyboardScreen.typeText(testPhrase)
        
        keyboardScreen.clearButton.element(boundBy: 1).tap()
        XCTAssertFalse(keyboardScreen.keyboardTextView.staticTexts[""].exists, "Expected the text view to be empty")
    }
    
    /*
     // My sayings is being replaced with Custom Categories so this test will no longer apply.
    func testWhenAddingPhraseToMySayings_ThenItAppearsOnMainScreen() {
        mainScreen.keyboardNavButton.tap()
        keyboardScreen.typeText(testPhrase)
        keyboardScreen.favoriteButton.tap()
        keyboardScreen.dismissKeyboardButton.tap()
        mainScreen.scrollLeftAndTapCurrentCategory(numTimesToScroll: 1)

        XCTAssert(mainScreen.isTextDisplayed(testPhrase), "Expected the phrase \(testPhrase) to be added to an displayed in 'My Sayings'")
    }
    */
}
