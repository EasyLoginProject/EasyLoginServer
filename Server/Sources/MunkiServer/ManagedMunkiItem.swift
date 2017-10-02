//
//  ManagedMunkiItem.swift
//  EasyLogin
//
//  Created by Yoann Gini on 29/09/2017.
//
//

// YGI (2017 oct): this file need a really big improvement
// We must be able to factorize most of this work via a list of property to handle and a for in
// Current implemention is way too prone to typo errors

import Foundation
import CouchDB
import Kitura
import DataProvider
import SwiftyJSON
import Extensions

public class ManagedMunkiItem : DataProvider.ManagedObject {
    override public class var objectType : String {return "munki_item"}
    
    enum ManagedMunkiItemKey : String {
        case autoremove
        case blocking_applications
        case catalogs
        case description
        case developer
        case display_name
        case force_install_after_date
        case icon_name
        case installable_condition
        case installed_size
        case installer_choices_xml
        case installer_environment
        case installer_item_hash
        case installer_item_location
        case installer_type
        case installs
        case items_to_copy
        case minimum_munki_version
        case minimum_os_version
        case maximum_os_version
        case name
        case notes
        case package_complete_url = "PackageCompleteURL"
        case package_path
        case installcheck_script
        case uninstallcheck_script
        case on_demand = "OnDemand"
        case postinstall_script
        case postuninstall_script
        case preinstall_alert
        case preuninstall_alert
        case preinstall_script
        case preuninstall_script
        case receipts
        case requires
        case restart_action = "RestartAction"
        case supported_architectures
        case suppress_bundle_relocation
        case unattended_install
        case unattended_uninstall
        case uninstall_method
        case uninstall_script
        case uninstaller_item_location
        case uninstallable
        case update_for
        case version
    }
    // TODO: Support Adobe specific keys
    public fileprivate(set) var catalogs: [String]
    public fileprivate(set) var description: String
    public fileprivate(set) var developer: String
    public fileprivate(set) var display_name: String
    public fileprivate(set) var installer_type: String
    public fileprivate(set) var name: String
    
    public fileprivate(set) var autoremove: Bool?
    public fileprivate(set) var blocking_applications: [String]?
    public fileprivate(set) var force_install_after_date: Date?
    public fileprivate(set) var icon_name: String?
    public fileprivate(set) var installable_condition: String?
    public fileprivate(set) var installed_size: Int?
    public fileprivate(set) var installer_choices_xml: [[String:Any]]?
    public fileprivate(set) var installer_environment: [String:String]?
    public fileprivate(set) var installer_item_hash: String?
    public fileprivate(set) var installer_item_location: String?
    public fileprivate(set) var installs: [[String:String]]?
    public fileprivate(set) var items_to_copy: [[String:String]]?
    public fileprivate(set) var minimum_munki_version: String?
    public fileprivate(set) var minimum_os_version: String?
    public fileprivate(set) var maximum_os_version: String?
    public fileprivate(set) var notes: String?
//    public fileprivate(set) var package_complete_url: String? // Should it be a var or a computer property?
    public fileprivate(set) var package_path: String?
    public fileprivate(set) var installcheck_script: String?
    public fileprivate(set) var uninstallcheck_script: String?
    public fileprivate(set) var on_demand: Bool?
    public fileprivate(set) var postinstall_script: String?
    public fileprivate(set) var postuninstall_script: String?
    public fileprivate(set) var preinstall_alert: [String:String]?
    public fileprivate(set) var preuninstall_alert: [String:String]?
    public fileprivate(set) var preinstall_script: String?
    public fileprivate(set) var preuninstall_script: String?
    public fileprivate(set) var receipts: [[String:Any]]?
    public fileprivate(set) var requires: [String]?
    public fileprivate(set) var restart_action: String?
    public fileprivate(set) var supported_architectures: [String]?
    public fileprivate(set) var suppress_bundle_relocation: Bool?
    public fileprivate(set) var unattended_install: Bool?
    public fileprivate(set) var unattended_uninstall: Bool?
    public fileprivate(set) var uninstall_method: String?
    public fileprivate(set) var uninstall_script: String?
    public fileprivate(set) var uninstaller_item_location: String?
    public fileprivate(set) var uninstallable: Bool?
    public fileprivate(set) var update_for: [String]?
    public fileprivate(set) var version: [String]?
    
    
    required public init(databaseRecord:JSON) throws {
        
        // YGI (2017 oct): I really miss KVC…
        catalogs = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.catalogs.rawValue)
        description = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.description.rawValue)
        developer = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.developer.rawValue)
        display_name = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.display_name.rawValue)
        installer_type = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.installer_type.rawValue)
        name = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.name.rawValue)
        
        autoremove = databaseRecord.optionalElement(ManagedMunkiItemKey.autoremove.rawValue)
        blocking_applications = databaseRecord.optionalElement(ManagedMunkiItemKey.blocking_applications.rawValue)
        force_install_after_date = databaseRecord.optionalElement(ManagedMunkiItemKey.force_install_after_date.rawValue)
        icon_name = databaseRecord.optionalElement(ManagedMunkiItemKey.icon_name.rawValue)
        installable_condition = databaseRecord.optionalElement(ManagedMunkiItemKey.installable_condition.rawValue)
        installed_size = databaseRecord.optionalElement(ManagedMunkiItemKey.installed_size.rawValue)
        installer_choices_xml = databaseRecord.optionalElement(ManagedMunkiItemKey.installer_choices_xml.rawValue)
        installer_environment = databaseRecord.optionalElement(ManagedMunkiItemKey.installer_environment.rawValue)
        installer_item_hash = databaseRecord.optionalElement(ManagedMunkiItemKey.installer_item_hash.rawValue)
        installer_item_location = databaseRecord.optionalElement(ManagedMunkiItemKey.installer_item_location.rawValue)
        installs = databaseRecord.optionalElement(ManagedMunkiItemKey.installs.rawValue)
        items_to_copy = databaseRecord.optionalElement(ManagedMunkiItemKey.items_to_copy.rawValue)
        minimum_munki_version = databaseRecord.optionalElement(ManagedMunkiItemKey.minimum_munki_version.rawValue)
        minimum_os_version = databaseRecord.optionalElement(ManagedMunkiItemKey.minimum_os_version.rawValue)
        maximum_os_version = databaseRecord.optionalElement(ManagedMunkiItemKey.maximum_os_version.rawValue)
        notes = databaseRecord.optionalElement(ManagedMunkiItemKey.notes.rawValue)
//        package_complete_url = databaseRecord.optionalElement(ManagedMunkiItemKey.package_complete_url.rawValue)
        package_path = databaseRecord.optionalElement(ManagedMunkiItemKey.package_path.rawValue)
        installcheck_script = databaseRecord.optionalElement(ManagedMunkiItemKey.installcheck_script.rawValue)
        uninstallcheck_script = databaseRecord.optionalElement(ManagedMunkiItemKey.uninstallcheck_script.rawValue)
        on_demand = databaseRecord.optionalElement(ManagedMunkiItemKey.on_demand.rawValue)
        postinstall_script = databaseRecord.optionalElement(ManagedMunkiItemKey.postinstall_script.rawValue)
        postuninstall_script = databaseRecord.optionalElement(ManagedMunkiItemKey.postuninstall_script.rawValue)
        preinstall_alert = databaseRecord.optionalElement(ManagedMunkiItemKey.preinstall_alert.rawValue)
        preuninstall_alert = databaseRecord.optionalElement(ManagedMunkiItemKey.preuninstall_alert.rawValue)
        preinstall_script = databaseRecord.optionalElement(ManagedMunkiItemKey.preinstall_script.rawValue)
        preuninstall_script = databaseRecord.optionalElement(ManagedMunkiItemKey.preuninstall_script.rawValue)
        receipts = databaseRecord.optionalElement(ManagedMunkiItemKey.receipts.rawValue)
        requires = databaseRecord.optionalElement(ManagedMunkiItemKey.requires.rawValue)
        restart_action = databaseRecord.optionalElement(ManagedMunkiItemKey.restart_action.rawValue)
        supported_architectures = databaseRecord.optionalElement(ManagedMunkiItemKey.supported_architectures.rawValue)
        suppress_bundle_relocation = databaseRecord.optionalElement(ManagedMunkiItemKey.suppress_bundle_relocation.rawValue)
        unattended_install = databaseRecord.optionalElement(ManagedMunkiItemKey.unattended_install.rawValue)
        unattended_uninstall = databaseRecord.optionalElement(ManagedMunkiItemKey.unattended_uninstall.rawValue)
        uninstall_method = databaseRecord.optionalElement(ManagedMunkiItemKey.uninstall_method.rawValue)
        uninstall_script = databaseRecord.optionalElement(ManagedMunkiItemKey.uninstall_script.rawValue)
        uninstaller_item_location = databaseRecord.optionalElement(ManagedMunkiItemKey.uninstaller_item_location.rawValue)
        uninstallable = databaseRecord.optionalElement(ManagedMunkiItemKey.uninstallable.rawValue)
        update_for = databaseRecord.optionalElement(ManagedMunkiItemKey.update_for.rawValue)
        version = databaseRecord.optionalElement(ManagedMunkiItemKey.version.rawValue)
        
        try super.init(databaseRecord: databaseRecord)
    }
    
    override open func mandatoryPropertiesForDictionaryRepresentation() -> [String:String] {
        return [
            "catalogs": ManagedMunkiItemKey.catalogs.rawValue,
            "description": ManagedMunkiItemKey.description.rawValue,
            "developer": ManagedMunkiItemKey.developer.rawValue,
            "display_name": ManagedMunkiItemKey.display_name.rawValue,
            "installer_type": ManagedMunkiItemKey.installer_type.rawValue,
            "name": ManagedMunkiItemKey.name.rawValue,
        ]
    }
    
    override open func optionalPropertiesForDictionaryRepresentation() -> [String:String] {
        return [
            "autoremove": ManagedMunkiItemKey.autoremove.rawValue,
            "blocking_applications": ManagedMunkiItemKey.blocking_applications.rawValue,
            "force_install_after_date": ManagedMunkiItemKey.force_install_after_date.rawValue,
            "icon_name": ManagedMunkiItemKey.icon_name.rawValue,
            "installable_condition": ManagedMunkiItemKey.installable_condition.rawValue,
            "installed_size": ManagedMunkiItemKey.installed_size.rawValue,
            "installer_choices_xml": ManagedMunkiItemKey.installer_choices_xml.rawValue,
            "installer_environment": ManagedMunkiItemKey.installer_environment.rawValue,
            "installer_item_hash": ManagedMunkiItemKey.installer_item_hash.rawValue,
            "installer_item_location": ManagedMunkiItemKey.installer_item_location.rawValue,
            "installs": ManagedMunkiItemKey.installs.rawValue,
            "items_to_copy": ManagedMunkiItemKey.items_to_copy.rawValue,
            "minimum_munki_version": ManagedMunkiItemKey.minimum_munki_version.rawValue,
            "minimum_os_version": ManagedMunkiItemKey.minimum_os_version.rawValue,
            "maximum_os_version": ManagedMunkiItemKey.maximum_os_version.rawValue,
            "notes": ManagedMunkiItemKey.notes.rawValue,
            "package_complete_url": ManagedMunkiItemKey.package_complete_url.rawValue,
            "package_path": ManagedMunkiItemKey.package_path.rawValue,
            "installcheck_script": ManagedMunkiItemKey.installcheck_script.rawValue,
            "uninstallcheck_script": ManagedMunkiItemKey.uninstallcheck_script.rawValue,
            "on_demand": ManagedMunkiItemKey.on_demand.rawValue,
            "postinstall_script": ManagedMunkiItemKey.postinstall_script.rawValue,
            "postuninstall_script": ManagedMunkiItemKey.postuninstall_script.rawValue,
            "preinstall_alert": ManagedMunkiItemKey.preinstall_alert.rawValue,
            "preuninstall_alert": ManagedMunkiItemKey.preuninstall_alert.rawValue,
            "preinstall_script": ManagedMunkiItemKey.preinstall_script.rawValue,
            "preuninstall_script": ManagedMunkiItemKey.preuninstall_script.rawValue,
            "receipts": ManagedMunkiItemKey.receipts.rawValue,
            "requires": ManagedMunkiItemKey.requires.rawValue,
            "restart_action": ManagedMunkiItemKey.restart_action.rawValue,
            "supported_architectures": ManagedMunkiItemKey.supported_architectures.rawValue,
            "suppress_bundle_relocation": ManagedMunkiItemKey.suppress_bundle_relocation.rawValue,
            "unattended_install": ManagedMunkiItemKey.unattended_install.rawValue,
            "unattended_uninstall": ManagedMunkiItemKey.unattended_uninstall.rawValue,
            "uninstall_method": ManagedMunkiItemKey.uninstall_method.rawValue,
            "uninstall_script": ManagedMunkiItemKey.uninstall_script.rawValue,
            "uninstaller_item_location": ManagedMunkiItemKey.uninstaller_item_location.rawValue,
            "uninstallable": ManagedMunkiItemKey.uninstallable.rawValue,
            "update_for": ManagedMunkiItemKey.update_for.rawValue,
        ]
    }
    
}
