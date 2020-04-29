//
//  EditCategoryDetailViewController.swift
//  Vocable AAC
//
//  Created by Thomas Shealy on 3/31/20.
//  Copyright © 2020 WillowTree. All rights reserved.
//

import UIKit
import CoreData

final class EditCategoryDetailViewController: UIViewController, UICollectionViewDelegate {

    var category: Category!

    private enum EditCategoryItem: Int, CaseIterable {
        case showCategoryToggle
        case addPhrase
        case removeCategory
    }

    private let context = NSPersistentContainer.shared.viewContext
    private lazy var dataSource: UICollectionViewDiffableDataSource<Int, EditCategoryItem> = .init(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell in
        return self.collectionView(collectionView, cellForItemAt: indexPath, item: item)
    }

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var editButton: GazeableButton!
    @IBOutlet private weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(category != nil, "Category not provided")
        
        titleLabel.text = category.name
        editButton.isHidden = !category.isUserGenerated
        setupCollectionView()
    }

    // MARK: UICollectionViewDataSource
    
    private func updateDataSource() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, EditCategoryItem>()
        snapshot.appendSections([0])

        if AppConfig.editPhrasesEnabled {
            snapshot.appendItems([.showCategoryToggle, .addPhrase, .removeCategory])
        } else {
            snapshot.appendItems([.showCategoryToggle, .removeCategory])
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.backgroundColor = .collectionViewBackgroundColor
        collectionView.allowsMultipleSelection = true
        collectionView.allowsSelection = true
        collectionView.delaysContentTouches = false

        collectionView.register(UINib(nibName: "EditCategoryToggleCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: EditCategoryToggleCollectionViewCell.reuseIdentifier)
        collectionView.register(UINib(nibName: "EditCategoryRemoveCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: EditCategoryRemoveCollectionViewCell.reuseIdentifier)
        collectionView.register(UINib(nibName: "SettingsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: SettingsCollectionViewCell.reuseIdentifier)
        
        updateDataSource()
        
        let layout = createLayout()
        collectionView.collectionViewLayout = layout
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let showCategoryToggleItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        showCategoryToggleItem.contentInsets = .init(top: 8, leading: 0, bottom: 8, trailing: 0)
        
        var showRemoveCategoryGroupFractionalHeight: NSCollectionLayoutDimension {
            if case .compact = traitCollection.verticalSizeClass {
                return .fractionalHeight(1 / 3)
            }
            return .fractionalHeight(1 / 8)
        }
        
        let showRemoveCategoryGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: showRemoveCategoryGroupFractionalHeight)
        let showRemoveCategoryGroup = NSCollectionLayoutGroup.vertical(layoutSize: showRemoveCategoryGroupSize, subitems: [showCategoryToggleItem])
        
        let section = NSCollectionLayoutSection(group: showRemoveCategoryGroup)
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        collectionView.setCollectionViewLayout(createLayout(), animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        titleLabel.text = category.name
    }

    private func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath, item: EditCategoryItem) -> UICollectionViewCell {
        switch item {
        case .showCategoryToggle:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EditCategoryToggleCollectionViewCell.reuseIdentifier, for: indexPath) as! EditCategoryToggleCollectionViewCell
            cell.isEnabled = shouldEnableItem(at: indexPath)
            cell.textLabel.text = NSLocalizedString("category_editor.detail.button.show_category.title", comment: "Show category button label within the category detail screen.")

            if let category = category {
                cell.showCategorySwitch.isOn = !category.isHidden
                cell.showCategorySwitch.isEnabled = (category.identifier != .userFavorites)
            }
            return cell

        case .addPhrase:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SettingsCollectionViewCell.reuseIdentifier, for: indexPath) as! SettingsCollectionViewCell
            let title = NSLocalizedString("MISSING_LOCALIZATION_Add Phrases", comment: "Add Phrases")
            cell.setup(title: title, image: UIImage(systemName: "chevron.right"))
            cell.isEnabled = shouldEnableItem(at: indexPath)
            return cell

        case .removeCategory:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EditCategoryRemoveCollectionViewCell.reuseIdentifier, for: indexPath) as! EditCategoryRemoveCollectionViewCell
            cell.isEnabled = shouldEnableItem(at: indexPath)
            cell.textLabel.text = NSLocalizedString("category_editor.detail.button.remove_category.title", comment: "Remove category button label within the category detail screen.")
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else { return }
        if collectionView.indexPathForGazedItem != indexPath {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
        switch selectedItem {
        case .showCategoryToggle:
            handleToggle(at: indexPath)
        case .addPhrase:
            displayEditPhrasesViewController()
        case .removeCategory:
            handleRemoveCategory()
        }
    }

    @IBAction func backButtonPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func editCategoryButtonPressed(_ sender: Any) {
        let vc = UIStoryboard(name: "EditTextViewController", bundle: nil).instantiateViewController(identifier: "EditTextViewController") as! EditTextViewController
        vc.modalPresentationStyle = .fullScreen
        vc.initialText = category.name ?? ""
        vc.editTextCompletionHandler = { (newText) -> Void in
            let context = NSPersistentContainer.shared.viewContext

            if let categoryIdentifier = self.category.identifier {
                let originalCategory = Category.fetchObject(in: context, matching: categoryIdentifier)
                originalCategory?.name = newText
            }
            do {
                try Category.updateAllOrdinalValues(in: context)
                try context.save()

                let alertMessage = NSLocalizedString("category_editor.toast.successfully_saved.title", comment: "User edited name of the category and saved it successfully")

                ToastWindow.shared.presentEphemeralToast(withTitle: alertMessage)
            } catch {
                assertionFailure("Failed to save category: \(error)")
            }
        }
        present(vc, animated: true)
    }

    private func shouldEnableItem(at indexPath: IndexPath) -> Bool {
        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else { return false }

        switch selectedItem {
        case .showCategoryToggle:
            return (category.identifier != .userFavorites)
        case .addPhrase, .removeCategory:
            return category.isUserGenerated
        }
    }
    
    private func handleToggle(at indexPath: IndexPath) {
        guard let category = category, let cell = collectionView.cellForItem(at: indexPath) as? EditCategoryToggleCollectionViewCell else { return }

        let shouldShowCategory = !cell.showCategorySwitch.isOn
        category.setValue(!category.isHidden, forKey: "isHidden")
        cell.showCategorySwitch.isOn = shouldShowCategory
        saveContext()
    }

    private func displayEditPhrasesViewController() {
        if let viewController = UIStoryboard(name: "EditPhrases", bundle: nil).instantiateViewController(identifier: "MyPhrases") as? EditPhrasesViewController {
            viewController.category = category
            show(viewController, sender: nil)
        }
    }

    private func handleDismissAlert() {
        func confirmChangesAction() {
            self.dismiss(animated: true, completion: nil)
        }

        let title = NSLocalizedString("category_editor.alert.cancel_editing_confirmation.title", comment: "Exit edit categories alert title")
        let confirmButtonTitle = NSLocalizedString("category_editor.alert.cancel_editing_confirmation.button.confirm_exit.title", comment: "Confirm exit category alert action title")
        let cancelButtonTitle = NSLocalizedString("category_editor.alert.cancel_editing_confirmation.button.cancel.title", comment: "Cancel exit editing alert action title")
        let alert = GazeableAlertViewController(alertTitle: title)
        alert.addAction(GazeableAlertAction(title: cancelButtonTitle))
        alert.addAction(GazeableAlertAction(title: confirmButtonTitle, style: .bold, handler: confirmChangesAction))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func handleRemoveCategory() {
        let title = NSLocalizedString("category_editor.alert.delete_category_confirmation.title", comment: "Remove category alert title")
        let confirmButtonTitle = NSLocalizedString("category_editor.alert.delete_category_confirmation.button.remove.title", comment: "Remove category alert action title")
        let cancelButtonTitle = NSLocalizedString("category_editor.alert.delete_category_confirmation.button.cancel.title", comment: "Cancel alert action title")
        let alert = GazeableAlertViewController(alertTitle: title)
        alert.addAction(GazeableAlertAction(title: confirmButtonTitle, handler: { self.removeCategory() }))
        alert.addAction(GazeableAlertAction(title: cancelButtonTitle, style: .bold, handler: { self.deselectCell() }))
        self.present(alert, animated: true)
    }
    
    private func removeCategory() {
       guard let category = category else { return }
        context.delete(category)
        saveContext()
        self.navigationController?.popViewController(animated: true)
    }
    
    private func deselectCell() {
        for path in collectionView.indexPathsForSelectedItems ?? [] {
            collectionView.deselectItem(at: path, animated: true)
        }
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to unsave user generated phrase: \(error)")
        }
    }
    
}
