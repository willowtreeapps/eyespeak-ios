//
//  EditCategoriesViewController.swift
//  Vocable
//
//  Created by Jesse Morgan on 3/31/20.
//  Copyright © 2020 WillowTree. All rights reserved.
//

import Foundation
import UIKit
import Combine
import CoreData

class EditCategoriesViewController: UIViewController {
    
    @IBOutlet private weak var pageNavigationView: PaginationView!
    
    private var carouselCollectionViewController: CarouselGridCollectionViewController?
    private var disposables = Set<AnyCancellable>()
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "CarouselCollectionViewController" {
           carouselCollectionViewController = segue.destination as? CarouselGridCollectionViewController
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       carouselCollectionViewController?.progressPublisher.sink(receiveValue: { (pagingProgress) in
            guard let pagingProgress = pagingProgress else {
                return
            }
            if pagingProgress.pageCount > 1 {
                self.pageNavigationView.setPaginationButtonsEnabled(true)
            } else {
                self.pageNavigationView.setPaginationButtonsEnabled(false)
            }
            let computedPageCount = max(pagingProgress.pageCount, 1)

            self.pageNavigationView.textLabel.text = String(format: NSLocalizedString("Page %d of %d", comment: ""), pagingProgress.pageIndex + 1, computedPageCount)
        }).store(in: &disposables)
        
        pageNavigationView.nextPageButton.addTarget(carouselCollectionViewController, action: #selector(CarouselGridCollectionViewController.scrollToNextPage), for: .primaryActionTriggered)
        pageNavigationView.previousPageButton.addTarget(carouselCollectionViewController, action: #selector(CarouselGridCollectionViewController.scrollToPreviousPage), for: .primaryActionTriggered)
        
    }
    
    @IBAction func backToEditCategories(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func addButtonPressed(_ sender: Any) {
        if let vc = UIStoryboard(name: "EditTextViewController", bundle: nil).instantiateViewController(identifier: "EditTextViewController") as? EditTextViewController {
            vc.editTextCompletionHandler = { (didChange, newText) -> Void in
                guard didChange else { return }
                let context = NSPersistentContainer.shared.viewContext

                _ = Category.create(withUserEntry: newText, in: context)
                do {
                    try Category.updateAllOrdinalValues(in: context)
                    try context.save()

                    let alertMessage = NSLocalizedString("Saved to Custom Categories", comment: "Saved to Custom Categories")

                    ToastWindow.shared.presentEphemeralToast(withTitle: alertMessage)
                } catch {
                    assertionFailure("Failed to save category: \(error)")
                }
            }
            
            vc.dismissalCompletionHandler = { (newText) -> Bool in
                return true
            }
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
    
}