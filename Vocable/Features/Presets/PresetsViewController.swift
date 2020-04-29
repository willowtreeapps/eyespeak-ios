//
//  TextSelectionViewController.swift
//  Vocable AAC
//
//  Created by Patrick Gatewood on 1/28/20.
//  Copyright © 2020 WillowTree. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData
import Combine

// swiftlint:disable type_body_length
class PresetsViewController: UICollectionViewController, VocableCollectionViewLayoutTransitioningDelegate {
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, ItemWrapper>!
    private var disposables = Set<AnyCancellable>()
    
    private var _textTransaction = TextTransaction(text: HintText.preset.localizedString)

    private var textTransaction: TextTransaction {
        return _textTransaction
    }
    
    let textExpression = TextExpression()
    
    enum Section: Int, CaseIterable {
        case textField
        case categories
        case predictiveText
        case presets
        case keyboard
    }
    
    enum ItemWrapper: Hashable {
        case textField(NSAttributedString)
        case topBarButton(TopBarButton)
        case paginatedCategories
        case suggestionText(TextSuggestion)
        case paginatedPresets(NSManagedObjectID?)
        case key(String)
        case keyboardFunctionButton(KeyboardFunctionButton)
        indirect case pageIndicator(ItemWrapper)
        indirect case pagination(ItemWrapper, UIPageViewController.NavigationDirection)
    }
    
    private var showKeyboard: Bool = false
    
    private var suggestions: [TextSuggestion]? {
        didSet {
            updateSnapshot()
        }
    }

    private var previousSnapshot: NSDiffableDataSourceSnapshot<Section, ItemWrapper>?
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    private func updateKeyboardKeys(in snapshot: inout NSDiffableDataSourceSnapshot<Section, ItemWrapper>) {

        guard snapshot.sectionIdentifiers.contains(.keyboard) else {
            return
        }

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .keyboard))

        if traitCollection.horizontalSizeClass == .compact && traitCollection.verticalSizeClass == .regular {
            snapshot.appendItems(KeyboardLocale.current.compactPortraitKeyMapping.map { ItemWrapper.key("\($0)") }, toSection: .keyboard)
        } else {
            snapshot.appendItems(KeyboardLocale.current.landscapeKeyMapping.map { ItemWrapper.key("\($0)") }, toSection: .keyboard)
        }

        snapshot.appendItems([.keyboardFunctionButton(.clear), .keyboardFunctionButton(.space), .keyboardFunctionButton(.backspace), .keyboardFunctionButton(.speak)], toSection: .keyboard)
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            var snapshot = self.dataSource.snapshot()
            if snapshot.sectionIdentifiers.contains(.keyboard) {
                self.updateKeyboardKeys(in: &snapshot)
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionView()
        configureDataSource(animated: false)
        observeItemSelectionChanges()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if dataSource.snapshot().indexOfSection(.presets) == nil {
            updateSnapshot()
        }
    }

    private func setupCollectionView() {
        collectionView.delaysContentTouches = false
        collectionView.isScrollEnabled = false
        
        collectionView.register(UINib(nibName: "TextFieldCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "TextFieldCollectionViewCell")
        collectionView.register(CategoryItemCollectionViewCell.self, forCellWithReuseIdentifier: CategoryItemCollectionViewCell.reuseIdentifier)
        collectionView.register(PresetItemCollectionViewCell.self, forCellWithReuseIdentifier: PresetItemCollectionViewCell.reuseIdentifier)
        collectionView.register(PaginationCollectionViewCell.self, forCellWithReuseIdentifier: PaginationCollectionViewCell.reuseIdentifier)
        collectionView.register(UINib(nibName: "CategoryPaginationContainerCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "CategoryPaginationContainerCollectionViewCell")
        collectionView.register(UINib(nibName: "PresetPaginationContainerCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "PresetPaginationContainerCollectionViewCell")
        collectionView.register(UINib(nibName: "KeyboardKeyCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "KeyboardKeyCollectionViewCell")
        collectionView.register(UINib(nibName: "FunctionKeyboardKeyCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "FunctionKeyboardKeyCollectionViewCell")
        collectionView.register(UINib(nibName: "SpeakFunctionKeyboardKeyCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SpeakFunctionKeyboardKeyCollectionViewCell")
        collectionView.register(UINib(nibName: "SuggestionCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SuggestionCollectionViewCell")
        collectionView.register(UINib(nibName: "PageIndicatorCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "PageIndicatorCollectionViewCell")
        collectionView.register(PresetPaginationCollectionViewCell.self, forCellWithReuseIdentifier: PresetPaginationCollectionViewCell.reuseIdentifier)
        collectionView.register(CategoryPaginationCollectionViewCell.self, forCellWithReuseIdentifier: CategoryPaginationCollectionViewCell.reuseIdentifier)
        
        let layout = createLayout()
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = UIColor.collectionViewBackgroundColor
        collectionView.allowsMultipleSelection = true
        
        collectionView.register(PresetPageControlReusableView.self, forSupplementaryViewOfKind: "footerPageIndicator", withReuseIdentifier: "PresetPageControlView")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = PresetCollectionViewCompositionalLayout { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            let sectionKind = self.dataSource.snapshot().sectionIdentifiers[sectionIndex]
            
            switch sectionKind {
            case .textField:
                if self.showKeyboard {
                    return PresetCollectionViewCompositionalLayout.topBarKeyboardSectionLayout(with: layoutEnvironment)
                }
                return PresetCollectionViewCompositionalLayout.topBarPresetSectionLayout(with: layoutEnvironment)
            case .categories:
                return PresetCollectionViewCompositionalLayout.categoriesSectionLayout(with: layoutEnvironment)
            case .predictiveText:
                return PresetCollectionViewCompositionalLayout.suggestiveTextSectionLayout(with: layoutEnvironment)
            case .presets:
                guard !self.showKeyboard else {
                    return nil
                }
                
                return PresetCollectionViewCompositionalLayout.presetsSectionLayout(with: layoutEnvironment)
            case .keyboard:
                return PresetCollectionViewCompositionalLayout.mainKeyboardLayout(with: layoutEnvironment)
            }
        }
        layout.register(CategorySectionBackground.self, forDecorationViewOfKind: "CategorySectionBackground")
        return layout
    }

    private func configureDataSource(animated: Bool = false) {
        dataSource = UICollectionViewDiffableDataSource<Section, ItemWrapper>(collectionView: collectionView, cellProvider: { (_: UICollectionView, indexPath: IndexPath, identifier: ItemWrapper) -> UICollectionViewCell? in
            
            switch identifier {
            case .textField(let title):
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: TextFieldCollectionViewCell.reuseIdentifier, for: indexPath) as! TextFieldCollectionViewCell
                cell.setup(title: title)
                cell.isCursorHidden = !self.showKeyboard
                return cell
            case .topBarButton(let buttonType):
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: PresetItemCollectionViewCell.reuseIdentifier, for: indexPath) as! PresetItemCollectionViewCell
                cell.setup(with: buttonType.image)
                return cell
            case .paginatedCategories:
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryPaginationContainerCollectionViewCell", for: indexPath) as! CategoryPaginationContainerCollectionViewCell
                return cell
            case .suggestionText(let predictiveText):
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: SuggestionCollectionViewCell.reuseIdentifier, for: indexPath) as! SuggestionCollectionViewCell
                cell.setup(title: predictiveText.text)
                return cell
            case .paginatedPresets(let categoryID):
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: "PresetPaginationContainerCollectionViewCell", for: indexPath) as! PresetPaginationContainerCollectionViewCell
                cell.presetCollectionViewController.categoryID = categoryID
                return cell
            case .key(let char):
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: KeyboardKeyCollectionViewCell.reuseIdentifier, for: indexPath) as! KeyboardKeyCollectionViewCell
                cell.setup(title: char)
                return cell
            case .keyboardFunctionButton(let functionType):
                if functionType == .speak {
                    let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: SpeakFunctionKeyboardKeyCollectionViewCell.reuseIdentifier, for: indexPath) as! SpeakFunctionKeyboardKeyCollectionViewCell
                    cell.setup(with: functionType.image)
                    return cell
                }
                let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: FunctionKeyboardKeyCollectionViewCell.reuseIdentifier, for: indexPath) as! FunctionKeyboardKeyCollectionViewCell
                cell.setup(with: functionType.image)
                return cell
            case .pageIndicator:
                return self.collectionView.dequeueReusableCell(withReuseIdentifier: "PageIndicatorCollectionViewCell", for: indexPath) as! PageIndicatorCollectionViewCell
            case .pagination(let itemIdentifier, let direction):
                switch itemIdentifier {
                case .paginatedCategories:
                    let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: CategoryPaginationCollectionViewCell.reuseIdentifier, for: indexPath) as! CategoryPaginationCollectionViewCell
                    cell.paginationDirection = direction
                    return cell
                case .paginatedPresets:
                    let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: PresetPaginationCollectionViewCell.reuseIdentifier, for: indexPath) as! PresetPaginationCollectionViewCell
                    
                    cell.paginationDirection = direction
                    return cell
                default:
                    break
                }
                return VocableCollectionViewCell()
            }
        })
        
        updateSnapshot(animated: animated, suppressingPhrases: true)
    }
    
    private func observeItemSelectionChanges() {
        _ = ItemSelection.$selectedPhrase.sink(receiveValue: { selectedPhrase in
            guard let utterance = selectedPhrase?.utterance else { return }
            self.setTextTransaction(TextTransaction(text: utterance))
        }).store(in: &disposables)

        _ = ItemSelection.$selectedCategoryID.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateSnapshot(animated: true)
            }
        }.store(in: &disposables)
    }
    
    // MARK: - NSDiffableDataSourceSnapshot construction

    private func phraseIsSaved(_ text: String) -> Bool {
        let context = NSPersistentContainer.shared.viewContext
        let fetchRequest: NSFetchRequest<Phrase> = Phrase.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSComparisonPredicate(\Phrase.utterance, .equalTo, text),
            NSComparisonPredicate(\Phrase.isUserGenerated, .equalTo, true)
        ])
        fetchRequest.fetchLimit = 1
        let numberOfResults = (try? context.count(for: fetchRequest)) ?? 0
        return numberOfResults > 0
    }

    func updateSnapshot(animated: Bool = true, suppressingPhrases: Bool = false) {

        let suggestions = self.suggestions ?? []
        let previousSnapshot = dataSource.snapshot()
        self.previousSnapshot = previousSnapshot
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemWrapper>()
        
        // Helper functions
        func appendSaveButton() {
            if phraseIsSaved(textTransaction.text) {
                snapshot.appendItems([.topBarButton(.unsave)])
            } else {
                snapshot.appendItems([.topBarButton(.save)])
            }
        }
        
        // Snapshot construction
        snapshot.appendSections([.textField])
        snapshot.appendItems([.textField(textTransaction.attributedText)])
        
        if showKeyboard {
            appendSaveButton()
            snapshot.appendItems([.topBarButton(.togglePreset), .topBarButton(.settings)])
            
            snapshot.appendSections([.predictiveText])
            
            if suggestions.isEmpty {
                 snapshot.appendItems([.suggestionText(TextSuggestion(text: "")),
                                       .suggestionText(TextSuggestion(text: "")),
                                       .suggestionText(TextSuggestion(text: "")),
                                       .suggestionText(TextSuggestion(text: ""))])
            } else {
                snapshot.appendItems([.suggestionText(TextSuggestion(text: (suggestions[safe: 0]?.text ?? ""))),
                                      .suggestionText(TextSuggestion(text: (suggestions[safe: 1]?.text ?? ""))),
                                      .suggestionText(TextSuggestion(text: (suggestions[safe: 2]?.text ?? ""))),
                                      .suggestionText(TextSuggestion(text: (suggestions[safe: 3]?.text ?? "")))])
            }
            
            snapshot.appendSections([.keyboard])
            updateKeyboardKeys(in: &snapshot)

        } else {
            snapshot.appendItems([.topBarButton(.toggleKeyboard), .topBarButton(.settings)])
            
            snapshot.appendSections([.categories])
            snapshot.appendItems([.pagination(.paginatedCategories, .reverse)])
            snapshot.appendItems([.paginatedCategories])
            snapshot.appendItems([.pagination(.paginatedCategories, .forward)])

            if !suppressingPhrases {
                let presetsItem = ItemWrapper.paginatedPresets(ItemSelection.selectedCategoryID)
                snapshot.appendSections([.presets])
                snapshot.appendItems([presetsItem])
                snapshot.appendItems([.pagination(presetsItem, .reverse), .pageIndicator(presetsItem), .pagination(presetsItem, .forward)])
            }
        }

        dataSource.apply(snapshot, animatingDifferences: animated, completion: {
            if let previous = self.previousSnapshot, previousSnapshot.sectionIdentifiers == previous.sectionIdentifiers, previousSnapshot.itemIdentifiers == previous.itemIdentifiers {
                self.previousSnapshot = nil
            }
        })
    }
    
    // MARK: - PresetCollectionViewCompositionalLayoutDelegate

    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        
        switch item {
        case .pagination(let itemIdentifier, _):
            switch itemIdentifier {
            case .paginatedPresets:
                let pageProgress = ItemSelection.presetsPageIndicatorProgress
                return pageProgress.pageCount > 1
            default:
                return true
            }
        case .textField, .paginatedCategories, .paginatedPresets, .pageIndicator:
            return false
        case .topBarButton, .keyboardFunctionButton, .key:
            return true
        case .suggestionText(let suggestion):
            return !suggestion.text.isEmpty
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        
        switch item {
        case .pagination(let itemIdentifier, _):
            switch itemIdentifier {
            case .paginatedPresets:
                let pageProgress = ItemSelection.presetsPageIndicatorProgress
                return pageProgress.pageCount > 1
            default:
                return true
            }
        case .textField, .paginatedCategories, .paginatedPresets, .pageIndicator:
            return false
        case .topBarButton, .keyboardFunctionButton, .key:
            return true
        case .suggestionText(let suggestion):
            return !suggestion.text.isEmpty
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        if let cell = cell as? TextFieldCollectionViewCell {
            cell.isCursorHidden = !showKeyboard
        }

        if let cell = cell as? PresetPaginationContainerCollectionViewCell {
            let childViewController = cell.presetCollectionViewController
            let childContainerView = cell.contentView
            
            addChild(childViewController)
            childViewController.view.frame = childContainerView.frame.inset(by: childContainerView.layoutMargins)
            childContainerView.addSubview(childViewController.view)
            childViewController.didMove(toParent: self)
        }
        
        if let cell = cell as? CategoryPaginationContainerCollectionViewCell,
            let childViewController = cell.categoryCollectionViewController {
            let childContainerView = cell.contentView
            
            addChild(childViewController)
            childViewController.view.frame = childContainerView.frame.inset(by:
                [traitCollection.horizontalSizeClass, traitCollection.verticalSizeClass].contains(.compact) ?
                    UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) : childContainerView.layoutMargins)
            childContainerView.addSubview(childViewController.view)
            childViewController.didMove(toParent: self)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        if let cell = cell as? TextFieldCollectionViewCell {
            cell.isCursorHidden = true
        }

        if let cell = cell as? PresetPaginationContainerCollectionViewCell {
            let childViewController = cell.presetCollectionViewController
            childViewController.willMove(toParent: nil)
            childViewController.removeFromParent()
            childViewController.view.removeFromSuperview()
        }
        
        if let cell = cell as? CategoryPaginationContainerCollectionViewCell,
            let childViewController = cell.categoryCollectionViewController {
            childViewController.willMove(toParent: nil)
            childViewController.removeFromParent()
            childViewController.view.removeFromSuperview()
        }
    }

    // swiftlint:disable cyclomatic_complexity
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else { return }
        
        for selectedPath in collectionView.indexPathsForSelectedItems ?? [] {
            if selectedPath.section == indexPath.section && selectedPath != indexPath {
                collectionView.deselectItem(at: selectedPath, animated: true)
            }
        }
        
        switch selectedItem {
        case .topBarButton(let buttonType):
            (self.view.window as? HeadGazeWindow)?.cancelActiveGazeTarget()
            collectionView.deselectItem(at: indexPath, animated: true)
            switch buttonType {
            case .unsave:
                let context = NSPersistentContainer.shared.viewContext
                guard let existing = Phrase.fetchObject(in: context, matching: textTransaction.text) else {
                    return
                }
                context.delete(existing)

                do {
                    try context.save()
                } catch {
                    assertionFailure("Failed to unsave user generated phrase: \(error)")
                }
                
                updateSnapshot()

            case .save:
                _textTransaction = TextTransaction(text: textTransaction.text.trimmingCharacters(in: .whitespacesAndNewlines), isHint: textTransaction.isHint)
                
                guard !textTransaction.isHint, !textTransaction.text.isEmpty else {
                    break
                }
                let context = NSPersistentContainer.shared.viewContext
                _ = Phrase.create(withUserEntry: textTransaction.text, in: context)

                do {
                    try context.save()

                    let toastString: String = {
                        let format = NSLocalizedString("phrase_editor.toast.successfully_saved_to_favorites.title_format", comment: "Saved to user favorites category toast title")
                        let categoryName = Category.userFavoritesCategoryName()
                        return String.localizedStringWithFormat(format, categoryName)
                    }()

                    ToastWindow.shared.presentEphemeralToast(withTitle: toastString)
                } catch {
                    assertionFailure("Failed to save user generated phrase: \(error)")
                }
                updateSnapshot()

            case .toggleKeyboard, .togglePreset:
                showKeyboard.toggle()
                
                // TODO: discuss with design if we want to cache the user's currently-entered text instead
                // of just clearing it

                let newText = showKeyboard ? HintText.keyboard.localizedString : HintText.preset.localizedString
                setTextTransaction(TextTransaction(text: newText, isHint: true))
            case .settings:
                presentSettingsViewController()
            default:
                break
            }
        case .keyboardFunctionButton(let functionType):
            switch functionType {
            case .space:
                setTextTransaction(textTransaction.appendingCharacter(with: " "))
            case .speak:
                guard !textTransaction.isHint else {
                    break
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    AVSpeechSynthesizer.shared.speak(self.textTransaction.text, language: AppConfig.activePreferredLanguageCode)
                }
            case .clear:
                setTextTransaction(TextTransaction(text: "", intent: .none))
            case .backspace:
                setTextTransaction(textTransaction.deletingLastToken())
            }
        case .key(let char):
            setTextTransaction(textTransaction.appendingCharacter(with: char))
        case .suggestionText(let suggestion):
            setTextTransaction(textTransaction.insertingSuggestion(with: suggestion.text))
        case .pagination(let itemIdentifier, let direction):  
            guard let contentItemIndexPath = dataSource.indexPath(for: itemIdentifier) else {
                break
            }
            
            if let paginationCell = collectionView.cellForItem(at: contentItemIndexPath) as? PresetPaginationContainerCollectionViewCell {
                paginationCell.paginate(direction)
            }
            
            if let paginationCell = collectionView.cellForItem(at: contentItemIndexPath) as? CategoryPaginationContainerCollectionViewCell {
                paginationCell.paginate(direction)
            }
        default:
            break
        }

        if collectionView.indexPathForGazedItem != indexPath {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        
        switch item {
        case .topBarButton, .keyboardFunctionButton, .key, .suggestionText, .pagination, .paginatedPresets, .pageIndicator:
            return true
        case .paginatedCategories, .textField:
            return false
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldTranslateEntranceAnimationForItemAt indexPath: IndexPath) -> Bool {
        let item = dataSource.itemIdentifier(for: indexPath)
        switch item {
        case .pagination(let item, _):
            switch item {
            case .paginatedPresets:
                return true
            default:
                return false
            }
        case .paginatedPresets, .key, .keyboardFunctionButton, .pageIndicator:
            return true
        default:
            return false
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldTranslateExitAnimationForItemAt indexPath: IndexPath) -> Bool {
        let previousItem: ItemWrapper? = {
            guard let previous = previousSnapshot else { return nil }
            let section = previous.sectionIdentifiers[indexPath.section]
            return previous.itemIdentifiers(inSection: section)[indexPath.item]
        }()
        let item = previousItem ?? dataSource.itemIdentifier(for: indexPath)
        switch item {
        case .pagination(let item, _):
            switch item {
            case .paginatedPresets:
                return true
            default:
                return false
            }
        case .paginatedPresets, .key, .keyboardFunctionButton, .pageIndicator:
            return true
        default:
            return false
        }
    }
    
    private func setTextTransaction(_ transaction: TextTransaction) {
        self._textTransaction = transaction
        
        // Update suggestions
        if textTransaction.isHint || textTransaction.text.last == " " {
            suggestions = []
        } else {
            textExpression.replace(text: textTransaction.text)
            suggestions = textExpression.suggestions().map({ TextSuggestion(text: $0) })
        }
    }
    
    private func presentSettingsViewController() {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let vc = storyboard.instantiateInitialViewController()!
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
}
