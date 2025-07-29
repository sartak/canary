//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

class KeyboardViewController: UIInputViewController {

    @IBOutlet var nextKeyboardButton: UIButton!
    private var keyA: UIButton!
    private var keyB: UIButton!
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        // Add custom view sizing constraints here
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupKeys()
        setupNextKeyboardButton()
        setupLayout()
    }
    
    private func setupKeys() {
        // Create key A
        keyA = UIButton(type: .system)
        keyA.setTitle("A", for: .normal)
        keyA.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        keyA.backgroundColor = UIColor.systemGray5
        keyA.layer.cornerRadius = 8
        keyA.translatesAutoresizingMaskIntoConstraints = false
        keyA.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
        
        // Create key B
        keyB = UIButton(type: .system)
        keyB.setTitle("B", for: .normal)
        keyB.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        keyB.backgroundColor = UIColor.systemGray5
        keyB.layer.cornerRadius = 8
        keyB.translatesAutoresizingMaskIntoConstraints = false
        keyB.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
        
        view.addSubview(keyA)
        view.addSubview(keyB)
    }
    
    private func setupNextKeyboardButton() {
        nextKeyboardButton = UIButton(type: .system)
        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        nextKeyboardButton.backgroundColor = UIColor.systemGray4
        nextKeyboardButton.layer.cornerRadius = 8
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        
        view.addSubview(nextKeyboardButton)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Key A
            keyA.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -60),
            keyA.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            keyA.widthAnchor.constraint(equalToConstant: 50),
            keyA.heightAnchor.constraint(equalToConstant: 50),
            
            // Key B
            keyB.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 60),
            keyB.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            keyB.widthAnchor.constraint(equalToConstant: 50),
            keyB.heightAnchor.constraint(equalToConstant: 50),
            
            // Next keyboard button
            nextKeyboardButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: 40),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func keyPressed(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        textDocumentProxy.insertText(title.lowercased())
    }
    
    override func viewWillLayoutSubviews() {
        self.nextKeyboardButton.isHidden = !self.needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
        
        var textColor: UIColor
        let proxy = self.textDocumentProxy
        if proxy.keyboardAppearance == UIKeyboardAppearance.dark {
            textColor = UIColor.white
        } else {
            textColor = UIColor.black
        }
        self.nextKeyboardButton.setTitleColor(textColor, for: [])
    }

}
