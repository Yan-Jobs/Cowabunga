//
//  AdvancedObject.swift
//  Cowabunga
//
//  Created by lemin on 2/7/23.
//

import Foundation
import MacDirtyCowSwift

enum ReplacingObjectType: String, CaseIterable {
    case FilePath = "File Path"
    case Imported = "Imported"
}

class AdvancedCategory: Identifiable {
    var id = UUID()
    var name: String
    var operations: [AdvancedCategory]?
    var categoryName: String?
    
    init(name: String, operations: [AdvancedCategory]? = nil, categoryName: String? = nil) {
        self.name = name
        self.operations = operations
        self.categoryName = categoryName
    }
}

class AdvancedObject: Identifiable {
    var id = UUID()
    
    var operationName: String
    var filePath: String
    var replacementData: Data? = nil
    var backupData: Data? = nil
    var applyInBackground: Bool
    
    init(operationName: String, filePath: String, applyInBackground: Bool, backupData: Data? = nil) {
        self.operationName = operationName
        self.filePath = filePath
        self.applyInBackground = applyInBackground
        self.backupData = backupData
    }
    
    func backup() throws {
        // back up the data at the file path
        backupData = try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
    
    func parseData() throws {
        // parse the data to be replaced
    }
    
    func applyData(fromBackup: Bool = false) throws {
        var newData: Data? = nil
        if fromBackup {
            newData = backupData
        } else {
            newData = replacementData
        }
        // applies the data only if it was parsed
        if newData != nil {
            if FileManager.default.fileExists(atPath: filePath) {
                // get data of and make sure it is smaller
                // first try to write normally
                do {
                    try newData!.write(to: URL(fileURLWithPath: filePath))
                } catch {
                    // if it fails, revert back to MDC
                    print("classic write failed... reverting back to MacDirtyCow")
                    do {
                        let originalSize = try Data(contentsOf: URL(fileURLWithPath: filePath)).count
                        if originalSize >= newData!.count {
                            let succeeded = MDC.overwriteFile(at: filePath, with: newData!)
                            if !succeeded {
                                throw "There was an error trying to write/replace the file."
                            }
                        } else {
                            throw "Replacement data is larger than the original file!"
                        }
                    } catch {
                        throw error.localizedDescription
                    }
                }
            } else {
                throw "No file exists at path!"
            }
        } else {
            if fromBackup {
                throw "No backup data was found!"
            } else {
                throw "Data not parsed before applying!"
            }
        }
    }
}

class NullObject: AdvancedObject {
    init() {
        super.init(operationName: "Null", filePath: "/", applyInBackground: false)
    }
}

class CorruptingObject: AdvancedObject {
    override func parseData() throws {
        // create empty data
        self.replacementData = Data("###".utf8)
    }
}

class ReplacingObject: AdvancedObject {
    var replacingType: ReplacingObjectType
    var replacingPath: String
    
    override func parseData() throws {
        // get the data from the files
        if FileManager.default.fileExists(atPath: self.replacingPath) {
            self.replacementData = try Data(contentsOf: URL(fileURLWithPath: self.replacingPath))
        } else {
            throw "No file exists at path \(self.replacingPath)!"
        }
    }
    
    init(operationName: String, filePath: String, applyInBackground: Bool, backupData: Data? = nil, overwriteData: Data, replacingType: ReplacingObjectType, replacingPath: String) {
        self.replacingType = replacingType
        self.replacingPath = replacingPath
        super.init(operationName: operationName, filePath: filePath, applyInBackground: applyInBackground, backupData: backupData)
        self.replacementData = overwriteData
    }
}

class PlistObject: AdvancedObject {
    var plistType: PropertyListSerialization.PropertyListFormat
    var replacingKeys: [String: Any] = [:]
    
    override func parseData() throws {
        // get the original plist file
        let plistData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as! [String: Any]
        var newPlist = plist
        for (k, v) in replacingKeys {
            newPlist = AdvancedManager.changeDictValue(newPlist, k, v)
        }
        // add empty data if binary
        if plistType == PropertyListSerialization.PropertyListFormat.binary {
            replacementData = try addEmptyData(matchingSize: plistData.count, to: newPlist)
        } else {
            replacementData = try PropertyListSerialization.data(fromPropertyList: newPlist, format: plistType, options: 0)
        }
    }
    
    init(operationName: String, filePath: String, applyInBackground: Bool, backupData: Data? = nil, plistType: PropertyListSerialization.PropertyListFormat, replacingKeys: [String: Any] = [:]) {
        self.plistType = plistType
        self.replacingKeys = replacingKeys
        super.init(operationName: operationName, filePath: filePath, applyInBackground: applyInBackground, backupData: backupData)
    }
}
