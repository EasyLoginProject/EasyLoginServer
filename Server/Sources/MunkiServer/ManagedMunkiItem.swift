//
//  ManagedMunkiItem.swift
//  EasyLogin
//
//  Created by Yoann Gini on 29/09/2017.
//
//

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
        // I really miss KVC…
        
        
        try super.init(databaseRecord: databaseRecord)
    }
    
    override open func dictionaryRepresentation() throws -> [String:Any] {
        var record = try super.dictionaryRepresentation()
        
        record[ManagedMunkiItemKey.catalogs.rawValue] = catalogs
        record[ManagedMunkiItemKey.description.rawValue] = description
        record[ManagedMunkiItemKey.developer.rawValue] = developer
        record[ManagedMunkiItemKey.display_name.rawValue] = display_name
        record[ManagedMunkiItemKey.installer_type.rawValue] = installer_type
        record[ManagedMunkiItemKey.name.rawValue] = name
        
        if let autoremove = autoremove {
            record[ManagedMunkiItemKey.autoremove.rawValue] = autoremove
        }
        if let blocking_applications = blocking_applications {
            record[ManagedMunkiItemKey.blocking_applications.rawValue] = blocking_applications
        }
        if let force_install_after_date = force_install_after_date {
            record[ManagedMunkiItemKey.force_install_after_date.rawValue] = force_install_after_date
        }
        if let icon_name = icon_name {
            record[ManagedMunkiItemKey.icon_name.rawValue] = icon_name
        }
        if let installable_condition = installable_condition {
            record[ManagedMunkiItemKey.installable_condition.rawValue] = installable_condition
        }
        if let installed_size = installed_size {
            record[ManagedMunkiItemKey.installed_size.rawValue] = installed_size
        }
        if let installer_choices_xml = installer_choices_xml {
            record[ManagedMunkiItemKey.installer_choices_xml.rawValue] = installer_choices_xml
        }
        if let installer_environment = installer_environment {
            record[ManagedMunkiItemKey.installer_environment.rawValue] = installer_environment
        }
        if let installer_item_hash = installer_item_hash {
            record[ManagedMunkiItemKey.installer_item_hash.rawValue] = installer_item_hash
        }
        if let installer_item_location = installer_item_location {
            record[ManagedMunkiItemKey.installer_item_location.rawValue] = installer_item_location
        }
        if let installs = installs {
            record[ManagedMunkiItemKey.installs.rawValue] = installs
        }
        if let items_to_copy = items_to_copy {
            record[ManagedMunkiItemKey.items_to_copy.rawValue] = items_to_copy
        }
        if let minimum_munki_version = minimum_munki_version {
            record[ManagedMunkiItemKey.minimum_munki_version.rawValue] = minimum_munki_version
        }
        if let minimum_os_version = minimum_os_version {
            record[ManagedMunkiItemKey.minimum_os_version.rawValue] = minimum_os_version
        }
        if let maximum_os_version = maximum_os_version {
            record[ManagedMunkiItemKey.maximum_os_version.rawValue] = maximum_os_version
        }
        if let notes = notes {
            record[ManagedMunkiItemKey.notes.rawValue] = notes
        }
//        if let package_complete_url = package_complete_url {
//            record[ManagedMunkiItemKey.package_complete_url.rawValue] = package_complete_url
//        }
        if let package_path = package_path {
            record[ManagedMunkiItemKey.package_path.rawValue] = package_path
        }
        if let installcheck_script = installcheck_script {
            record[ManagedMunkiItemKey.installcheck_script.rawValue] = installcheck_script
        }
        if let uninstallcheck_script = uninstallcheck_script {
            record[ManagedMunkiItemKey.uninstallcheck_script.rawValue] = uninstallcheck_script
        }
        if let on_demand = on_demand {
            record[ManagedMunkiItemKey.on_demand.rawValue] = on_demand
        }
        if let postinstall_script = postinstall_script {
            record[ManagedMunkiItemKey.postinstall_script.rawValue] = postinstall_script
        }
        if let postuninstall_script = postuninstall_script {
            record[ManagedMunkiItemKey.postuninstall_script.rawValue] = postuninstall_script
        }
        if let preinstall_alert = preinstall_alert {
            record[ManagedMunkiItemKey.preinstall_alert.rawValue] = preinstall_alert
        }
        if let preuninstall_alert = preuninstall_alert {
            record[ManagedMunkiItemKey.preuninstall_alert.rawValue] = preuninstall_alert
        }
        if let preinstall_script = preinstall_script {
            record[ManagedMunkiItemKey.preinstall_script.rawValue] = preinstall_script
        }
        if let preuninstall_script = preuninstall_script {
            record[ManagedMunkiItemKey.preuninstall_script.rawValue] = preuninstall_script
        }
        if let receipts = receipts {
            record[ManagedMunkiItemKey.receipts.rawValue] = receipts
        }
        if let requires = requires {
            record[ManagedMunkiItemKey.requires.rawValue] = requires
        }
        if let restart_action = restart_action {
            record[ManagedMunkiItemKey.restart_action.rawValue] = restart_action
        }
        if let supported_architectures = supported_architectures {
            record[ManagedMunkiItemKey.supported_architectures.rawValue] = supported_architectures
        }
        if let suppress_bundle_relocation = suppress_bundle_relocation {
            record[ManagedMunkiItemKey.suppress_bundle_relocation.rawValue] = suppress_bundle_relocation
        }
        if let unattended_install = unattended_install {
            record[ManagedMunkiItemKey.unattended_install.rawValue] = unattended_install
        }
        if let unattended_uninstall = unattended_uninstall {
            record[ManagedMunkiItemKey.unattended_uninstall.rawValue] = unattended_uninstall
        }
        if let uninstall_method = uninstall_method {
            record[ManagedMunkiItemKey.uninstall_method.rawValue] = uninstall_method
        }
        if let uninstall_script = uninstall_script {
            record[ManagedMunkiItemKey.uninstall_script.rawValue] = uninstall_script
        }
        if let uninstaller_item_location = uninstaller_item_location {
            record[ManagedMunkiItemKey.uninstaller_item_location.rawValue] = uninstaller_item_location
        }
        if let uninstallable = uninstallable {
            record[ManagedMunkiItemKey.uninstallable.rawValue] = uninstallable
        }
        if let update_for = update_for {
            record[ManagedMunkiItemKey.update_for.rawValue] = update_for
        }
        
        return record
    }
}
